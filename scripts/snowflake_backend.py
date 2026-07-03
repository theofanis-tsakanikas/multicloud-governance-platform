#!/usr/bin/env python3
"""Snowflake enforcement backend — translation + cross-backend consistency.

The governance contract (the per-domain JSON under ``environments/dev/domains/``) is
enforced today on **Databricks Unity Catalog**, where the abstract grant privilege *is*
the UC privilege — an identity mapping. This module is the **second enforcement backend**:
it translates the *same* :class:`governance_model.GovernanceModel` into **Snowflake**
grants, using ``infra/snowflake/privilege_map.json`` — the single source of truth that the
Snowflake Terraform reads too (via ``jsondecode``). One contract, two engines.

Everything here is offline, stdlib-only, credential-free (like the rest of the copilot).
Two responsibilities:

* :func:`render_snowflake_grants` — the structured Snowflake grant fragments (role,
  object, privileges, scope) the Terraform mirrors. Useful for a ``--render`` view and as
  the data the consistency check reasons over.
* :func:`effective_access` — the read / write / admin capability each principal holds on
  each object, computed **independently per engine** (UC from the model's own privilege
  taxonomy; Snowflake from an object-aware classifier of the *translated* privileges). A
  test asserts the Snowflake translation neither **loses** a capability the UC contract
  grants nor silently **adds** one — the engine-agnostic proof, mirroring how
  ``test_opa_consistency.py`` runs two engines over one context and asserts equal verdicts.

Why capability-level (not privilege-identity) equivalence: Snowflake and UC have different
vocabularies (Snowflake collapses UC ``BROWSE`` and ``READ_FILES`` both into stage
``USAGE``), so the honest invariant is that the *effective access* — can this principal
read / write / administer this object — is preserved. An *added* capability (a Snowflake
over-grant relative to the UC intent) is exactly the kind of least-privilege drift this
platform exists to surface, so it is reported, not hidden.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from governance_model import (
    ADMIN_PRIVILEGES,
    DATA_READ_PRIVILEGES,
    WRITE_PRIVILEGES,
    GovernanceModel,
    build_model,
)

# Capability labels — the vendor-neutral unit the two engines are compared on.
READ, WRITE, ADMIN = "read", "write", "admin"

PRIVILEGE_MAP_PATH = "infra/snowflake/privilege_map.json"


# --------------------------------------------------------------------------- #
# The shared privilege map (single source of truth, read by Terraform too)
# --------------------------------------------------------------------------- #


def load_privilege_map(repo_root: str | Path) -> dict:
    """Load ``infra/snowflake/privilege_map.json`` (the shared translation contract)."""
    path = Path(repo_root) / PRIVILEGE_MAP_PATH
    return json.loads(path.read_text(encoding="utf-8"))


@dataclass(frozen=True)
class SnowflakeGrant:
    """One Snowflake grant fragment — the unit the Terraform module renders.

    ``object_type`` is the abstract UC object type (``catalog`` / ``schema`` / ``volume`` /
    ``external_location``); ``snowflake_object_type`` is its Snowflake counterpart
    (``database`` / ``schema`` / ``stage``). ``scope`` says where the privilege attaches
    relative to the object (``self`` or ``future_and_existing_tables``), because Snowflake
    data privileges live on tables, not on the containing schema/database.
    """

    cloud: str
    domain: str
    object_type: str
    snowflake_object_type: str
    fqn: str
    principal: str
    privileges: tuple[str, ...]
    scope: str
    source_privilege: str  # the UC privilege this fragment was translated from


def snowflake_object_type(object_type: str, priv_map: dict) -> str:
    """Map an abstract UC object type to its Snowflake object type via the map."""
    return priv_map["object_type_map"].get(object_type, object_type)


def render_snowflake_grants(model: GovernanceModel, priv_map: dict) -> list[SnowflakeGrant]:
    """Translate every grant in ``model`` into Snowflake grant fragments.

    Mirrors, in Python, exactly what the Snowflake Terraform does with the same
    ``privilege_map.json`` (``jsondecode`` + lookup) — so this rendering and the applied
    infrastructure derive from one contract. Unmapped privileges are skipped defensively
    (``validate_domains`` already rejects privileges invalid for an object type, so this
    only guards genuinely un-translatable vocabulary).
    """
    table = priv_map["privilege_map"]
    out: list[SnowflakeGrant] = []
    for grant in model.grants:
        per_object = table.get(grant.object_type, {})
        sf_object_type = snowflake_object_type(grant.object_type, priv_map)
        for uc_priv in grant.privileges:
            for fragment in per_object.get(uc_priv, []):
                out.append(
                    SnowflakeGrant(
                        cloud=grant.cloud,
                        domain=grant.domain,
                        object_type=grant.object_type,
                        snowflake_object_type=sf_object_type,
                        fqn=grant.fqn,
                        principal=grant.principal,
                        privileges=tuple(fragment["privileges"]),
                        scope=fragment.get("scope", "self"),
                        source_privilege=uc_priv,
                    )
                )
    return out


# --------------------------------------------------------------------------- #
# Capability classifiers — INDEPENDENT per engine (this is what makes the
# consistency test meaningful rather than tautological)
# --------------------------------------------------------------------------- #


def abstract_capabilities(privileges: tuple[str, ...] | list[str]) -> frozenset[str]:
    """The read/write/admin capabilities a set of UC (abstract) privileges confer.

    Derived from the model's own privilege taxonomy (``DATA_READ_PRIVILEGES`` /
    ``WRITE_PRIVILEGES`` / ``ADMIN_PRIVILEGES``), so it is the abstract-contract truth.
    ``ALL_PRIVILEGES`` implies all three; structural/usage privileges (``USE_*``,
    ``CREATE_SCHEMA``, ``BROWSE``) confer none.
    """
    caps: set[str] = set()
    for p in privileges:
        if p == "ALL_PRIVILEGES":
            caps.update({READ, WRITE, ADMIN})
        if p in DATA_READ_PRIVILEGES:
            caps.add(READ)
        if p in WRITE_PRIVILEGES:
            caps.add(WRITE)
        if p in ADMIN_PRIVILEGES:
            caps.add(ADMIN)
    return frozenset(caps)


# Snowflake privilege -> capabilities, defined independently of the map. USAGE is
# object-aware: on a STAGE it grants read access to files (READ), on a database/schema it
# is traversal only. Structural container creation (CREATE SCHEMA) is not a data-write, to
# mirror the abstract taxonomy (which excludes CREATE_SCHEMA from WRITE_PRIVILEGES).
_SNOWFLAKE_WRITE = frozenset(
    {
        "INSERT",
        "UPDATE",
        "DELETE",
        "TRUNCATE",
        "WRITE",
        "CREATE TABLE",
        "CREATE STAGE",
        "CREATE MATERIALIZED VIEW",
        "CREATE FUNCTION",
        "CREATE MODEL",
    }
)
_SNOWFLAKE_ADMIN = frozenset({"APPLY TAG", "APPLYBUDGET", "MANAGE GRANTS", "OWNERSHIP"})


def snowflake_capabilities(snowflake_object_type: str, privileges: tuple[str, ...] | list[str]) -> frozenset[str]:
    """The read/write/admin capabilities a set of *Snowflake* privileges confer.

    Independent of the privilege map — classifies the resulting Snowflake privilege names
    directly, so a mistranslation that drops or adds a capability is caught.
    """
    caps: set[str] = set()
    for p in privileges:
        if p == "ALL PRIVILEGES":
            caps.update({READ, WRITE, ADMIN})
        elif p == "SELECT":
            caps.add(READ)
        elif p == "USAGE":
            # Stage USAGE = read files; database/schema USAGE = traversal only.
            if snowflake_object_type == "stage":
                caps.add(READ)
        elif p in _SNOWFLAKE_WRITE:
            caps.add(WRITE)
        elif p in _SNOWFLAKE_ADMIN:
            caps.add(ADMIN)
    return frozenset(caps)


# --------------------------------------------------------------------------- #
# Effective access per (object, principal) — the comparison surface
# --------------------------------------------------------------------------- #

# A stable key for an access-controlled object: (object_type, fqn, principal).
AccessKey = tuple[str, str, str]


def effective_access_uc(model: GovernanceModel) -> dict[AccessKey, frozenset[str]]:
    """Read/write/admin each principal holds on each object under the **UC** contract."""
    out: dict[AccessKey, set[str]] = {}
    for grant in model.grants:
        key = (grant.object_type, grant.fqn, grant.principal)
        out.setdefault(key, set()).update(abstract_capabilities(grant.privileges))
    return {k: frozenset(v) for k, v in out.items()}


def effective_access_snowflake(model: GovernanceModel, priv_map: dict) -> dict[AccessKey, frozenset[str]]:
    """Read/write/admin each principal holds on each object under the **Snowflake** backend."""
    out: dict[AccessKey, set[str]] = {}
    for sg in render_snowflake_grants(model, priv_map):
        key = (sg.object_type, sg.fqn, sg.principal)
        out.setdefault(key, set()).update(snowflake_capabilities(sg.snowflake_object_type, sg.privileges))
    return {k: frozenset(v) for k, v in out.items()}


@dataclass(frozen=True)
class ConsistencyIssue:
    """A cross-backend access divergence for one (object, principal)."""

    kind: str  # "lost" (Snowflake grants less than UC) | "added" (Snowflake grants more)
    object_type: str
    fqn: str
    principal: str
    uc_access: frozenset[str]
    snowflake_access: frozenset[str]

    def __str__(self) -> str:
        return (
            f"{self.kind.upper()} {self.object_type}:{self.fqn} / {self.principal}: "
            f"UC={sorted(self.uc_access)} Snowflake={sorted(self.snowflake_access)}"
        )


def cross_backend_issues(model: GovernanceModel, priv_map: dict) -> list[ConsistencyIssue]:
    """Compare the two backends' effective access; return divergences (empty == equivalent).

    ``lost``  — the Snowflake translation confers *less* than the UC contract (a real
    enforcement gap, the serious case). ``added`` — Snowflake confers *more* (an
    over-grant / least-privilege drift). Both keys' union is walked so an object/principal
    present in only one backend surfaces too.
    """
    uc = effective_access_uc(model)
    sf = effective_access_snowflake(model, priv_map)
    issues: list[ConsistencyIssue] = []
    for key in sorted(set(uc) | set(sf)):
        uc_access = uc.get(key, frozenset())
        sf_access = sf.get(key, frozenset())
        if uc_access == sf_access:
            continue
        object_type, fqn, principal = key
        if uc_access - sf_access:
            issues.append(ConsistencyIssue("lost", object_type, fqn, principal, uc_access, sf_access))
        if sf_access - uc_access:
            issues.append(ConsistencyIssue("added", object_type, fqn, principal, uc_access, sf_access))
    return issues


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    """CLI: render the Snowflake grant set, or check cross-backend consistency."""
    import argparse

    parser = argparse.ArgumentParser(description="Snowflake enforcement backend (translation + consistency).")
    parser.add_argument("--root", default=str(_default_repo_root()), help="repository root")
    parser.add_argument("--check", action="store_true", help="fail if the backends are not access-equivalent")
    parser.add_argument("--render", action="store_true", help="print the translated Snowflake grants")
    args = parser.parse_args(argv)

    root = Path(args.root)
    model = build_model(root)
    priv_map = load_privilege_map(root)

    if args.render:
        for sg in render_snowflake_grants(model, priv_map):
            print(f"GRANT {', '.join(sg.privileges)} ON {sg.snowflake_object_type} {sg.fqn} [{sg.scope}] TO ROLE {sg.principal}")

    issues = cross_backend_issues(model, priv_map)
    lost = [i for i in issues if i.kind == "lost"]
    added = [i for i in issues if i.kind == "added"]
    for i in issues:
        print(i)
    print(f"cross-backend consistency: {len(lost)} lost, {len(added)} added (over-grant)")

    if args.check and lost:
        print("RESULT: FAIL (Snowflake enforcement loses UC-granted access)")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
