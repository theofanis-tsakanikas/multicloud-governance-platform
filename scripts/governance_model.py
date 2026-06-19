#!/usr/bin/env python3
"""Shared governance model: parse the domain JSON into a normalized object graph.

The domain governance config lives in per-domain JSON under
``environments/dev/domains/<cloud>/`` (see ``validate_domains.py`` for the schema
and the Terraform consumption path). That JSON answers *what infrastructure to
create* — it is not shaped for *reasoning about access*.

This module is the single source of truth for the **governance reasoning layer**.
It flattens the infra + grants files into two simple, denormalized lists:

* ``Securable`` — every governable object (external location, catalog, schema,
  volume) with its data ``classification`` and ``owner``.
* ``Grant``     — every (principal → privileges) edge, with the target object's
  classification resolved onto it.

Both :mod:`policy_analyzer` (the deterministic least-privilege / PII gate) and
:mod:`governance_report` (the human + AI-Act documentation) consume this model,
so the parsing rules live in exactly one place.

The model is **read-only and offline**: it parses committed JSON, touches no
cloud, and needs no credentials — the same discipline as ``validate_domains``.

Data classification is an *additive* convention. Schemas may carry
``"classification"`` and catalogs may carry ``"owner"``; Terraform ignores both
(it consumes the JSON via ``jsondecode`` + ``merge``/``lookup``, so unknown keys
pass through harmlessly). A volume inherits its schema's classification unless it
declares its own.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from validate_domains import discover_domain_files, load_json

# --------------------------------------------------------------------------- #
# Classification taxonomy
#
# Ordered least → most sensitive. ``pii`` is personal data in scope of the GDPR
# / EU AI Act; everything an analyzer rule treats as "needs protection" is
# >= CONFIDENTIAL. ``None`` means a securable was never classified (a governance
# hygiene gap the analyzer surfaces).
# --------------------------------------------------------------------------- #

CLASSIFICATIONS: tuple[str, ...] = ("public", "internal", "confidential", "pii")
_CLASSIFICATION_RANK = {name: i for i, name in enumerate(CLASSIFICATIONS)}

# Privileges that read data (a confidentiality concern on classified objects).
READ_PRIVILEGES = frozenset({"SELECT", "READ_VOLUME", "READ_FILES", "BROWSE", "EXECUTE", "USE_SCHEMA", "USE_CATALOG"})
# Privileges that read the *contents* of data (stricter than READ_PRIVILEGES,
# which includes navigation-only grants like USE_SCHEMA).
DATA_READ_PRIVILEGES = frozenset({"SELECT", "READ_VOLUME", "READ_FILES"})
# Privileges that write/modify data.
WRITE_PRIVILEGES = frozenset({"MODIFY", "WRITE_VOLUME", "WRITE_FILES", "CREATE_TABLE", "CREATE_EXTERNAL_TABLE", "CREATE_EXTERNAL_VOLUME"})
# Privileges that can change access itself (privilege escalation surface).
ADMIN_PRIVILEGES = frozenset({"ALL_PRIVILEGES", "MANAGE"})


def classification_rank(classification: str | None) -> int:
    """Rank a classification (higher = more sensitive); unknown/None ranks -1."""
    if classification is None:
        return -1
    return _CLASSIFICATION_RANK.get(classification, -1)


def is_sensitive(classification: str | None) -> bool:
    """True for confidential or pii (the classes the policy rules protect)."""
    return classification_rank(classification) >= _CLASSIFICATION_RANK["confidential"]


# --------------------------------------------------------------------------- #
# Object graph
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Securable:
    """One governable Unity Catalog object."""

    cloud: str
    domain: str
    object_type: str  # external_location | catalog | schema | volume
    fqn: str  # location_name | catalog | catalog.schema | catalog.schema.volume
    classification: str | None = None
    owner: str | None = None
    catalog_type: str | None = None  # MANAGED | FEDERATED (carried onto schemas/volumes)
    connection_name: str | None = None  # federated catalogs only


@dataclass(frozen=True)
class Grant:
    """One (principal → privileges) edge on a securable."""

    cloud: str
    domain: str
    object_type: str
    fqn: str
    principal: str
    privileges: tuple[str, ...]
    classification: str | None = None  # resolved from the target securable
    catalog_type: str | None = None


@dataclass
class GovernanceModel:
    """The whole platform's governance graph, flattened for reasoning."""

    securables: list[Securable] = field(default_factory=list)
    grants: list[Grant] = field(default_factory=list)

    # -- lookups ---------------------------------------------------------- #

    def securable(self, object_type: str, fqn: str) -> Securable | None:
        for s in self.securables:
            if s.object_type == object_type and s.fqn == fqn:
                return s
        return None

    def classification_of(self, object_type: str, fqn: str) -> str | None:
        s = self.securable(object_type, fqn)
        return s.classification if s else None

    def principals(self) -> set[str]:
        return {g.principal for g in self.grants}

    def domains(self) -> list[tuple[str, str]]:
        """Distinct (cloud, domain) pairs, in first-seen order."""
        seen: list[tuple[str, str]] = []
        for s in self.securables:
            key = (s.cloud, s.domain)
            if key not in seen:
                seen.append(key)
        return seen

    def grants_on_classified(self, *, minimum: str = "confidential") -> list[Grant]:
        """Grants whose target object is classified at or above ``minimum``."""
        floor = _CLASSIFICATION_RANK.get(minimum, 0)
        return [g for g in self.grants if classification_rank(g.classification) >= floor]


# --------------------------------------------------------------------------- #
# Parsing
# --------------------------------------------------------------------------- #


def _build_securables(infra: dict, cloud: str, domain: str) -> tuple[list[Securable], dict[str, str | None]]:
    """Flatten one infra file into securables. Returns (securables, classification_index).

    The classification index maps ``object_type:fqn`` → classification so the
    grant parser can resolve a grant's sensitivity without re-walking the tree.
    """
    securables: list[Securable] = []
    classification: dict[str, str | None] = {}

    def remember(s: Securable) -> None:
        securables.append(s)
        classification[f"{s.object_type}:{s.fqn}"] = s.classification

    for el in infra.get("external_locations", []) or []:
        name = el.get("location_name")
        if isinstance(name, str) and name:
            # External locations are storage mounts, not classified data objects.
            remember(Securable(cloud, domain, "external_location", name))

    for cat in infra.get("catalogs", []) or []:
        cname = cat.get("catalog_name")
        if not isinstance(cname, str) or not cname:
            continue
        ctype = cat.get("type") if isinstance(cat.get("type"), str) else None
        remember(
            Securable(
                cloud,
                domain,
                "catalog",
                cname,
                owner=cat.get("owner") if isinstance(cat.get("owner"), str) else None,
                catalog_type=ctype,
                connection_name=cat.get("connection_name") if isinstance(cat.get("connection_name"), str) else None,
            )
        )

        for sch in cat.get("schemas", []) or []:
            sname = sch.get("schema_name")
            if not isinstance(sname, str) or not sname:
                continue
            sclass = sch.get("classification") if isinstance(sch.get("classification"), str) else None
            schema_fqn = f"{cname}.{sname}"
            remember(Securable(cloud, domain, "schema", schema_fqn, classification=sclass, catalog_type=ctype))

            for vol in sch.get("volumes", []) or []:
                vname = vol.get("volume_name")
                if not isinstance(vname, str) or not vname:
                    continue
                # A volume inherits its schema's classification unless it sets its own.
                vclass = vol.get("classification") if isinstance(vol.get("classification"), str) else sclass
                remember(Securable(cloud, domain, "volume", f"{schema_fqn}.{vname}", classification=vclass, catalog_type=ctype))

    return securables, classification


_GRANT_SECTIONS = (
    ("external_location_grants", "location_name", "external_location"),
    ("catalog_grants", "catalog_name", "catalog"),
    ("schema_grants", "schema", "schema"),
    ("volume_grants", "volume", "volume"),
)


def _build_grants(
    grants_doc: dict,
    cloud: str,
    domain: str,
    classification_index: dict[str, str | None],
    catalog_type_index: dict[str, str | None],
) -> list[Grant]:
    """Flatten one grants file into ``Grant`` edges with classification resolved."""
    out: list[Grant] = []
    for section, key, object_type in _GRANT_SECTIONS:
        for entry in grants_doc.get(section, []) or []:
            if not isinstance(entry, dict):
                continue
            fqn = entry.get(key)
            if not isinstance(fqn, str) or not fqn:
                continue
            cls = classification_index.get(f"{object_type}:{fqn}")
            ctype = catalog_type_index.get(f"{object_type}:{fqn}")
            for g in entry.get("grants", []) or []:
                if not isinstance(g, dict):
                    continue
                principal = g.get("principal")
                privs = g.get("privileges")
                if not isinstance(principal, str) or not principal:
                    continue
                if not isinstance(privs, list):
                    continue
                out.append(
                    Grant(
                        cloud=cloud,
                        domain=domain,
                        object_type=object_type,
                        fqn=fqn,
                        principal=principal,
                        privileges=tuple(p for p in privs if isinstance(p, str)),
                        classification=cls,
                        catalog_type=ctype,
                    )
                )
    return out


def build_model(repo_root: str | Path) -> GovernanceModel:
    """Parse every domain JSON pair under the repo into a single GovernanceModel.

    Assumes the config is already schema-valid (run ``validate_domains`` first in
    CI). Malformed entries are skipped defensively rather than raising, so the
    analyzer/report degrade gracefully instead of crashing on a bad file.
    """
    repo_root = Path(repo_root).resolve()
    model = GovernanceModel()

    for infra_path, grants_path in discover_domain_files(repo_root):
        infra, _ = load_json(infra_path)
        if not isinstance(infra, dict):
            continue
        cloud = str(infra.get("cloud", "?"))
        domain = str(infra.get("domain", "?"))

        securables, classification_index = _build_securables(infra, cloud, domain)
        model.securables.extend(securables)

        catalog_type_index = {f"{s.object_type}:{s.fqn}": s.catalog_type for s in securables}

        grants_doc, _ = load_json(grants_path)
        if isinstance(grants_doc, dict):
            model.grants.extend(_build_grants(grants_doc, cloud, domain, classification_index, catalog_type_index))

    return model
