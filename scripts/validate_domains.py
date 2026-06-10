#!/usr/bin/env python3
"""Offline validator for Databricks Unity Catalog domain governance config.

This project carries **no application logic** — its behaviour lives entirely in
the per-domain JSON config under ``environments/dev/domains/<cloud>/``. Those
files are consumed by the ``data_platform/dbx_governance`` Terragrunt configs
via ``jsondecode(file(...))`` and handed to Terraform as ``jsonencode``'d
inputs. A typo there does not fail fast: a mis-cased catalog ``type`` is
silently dropped by the HCL ``[for c if c.type == "MANAGED"]`` filter, and a
grant that points at a non-existent object only blows up mid-``apply``.

This module is a **pre-flight / CI check**. It is deliberately decoupled from
the Terraform/Terragrunt apply path — it touches no cloud, needs no
credentials, and is never invoked by `make apply`. It validates three things,
matching exactly how the HCL consumes the JSON:

1. SCHEMA       — each ``*_infra.json`` / ``*_grants.json`` is well-formed.
2. CONSISTENCY  — every grant points at an object that exists in infra, every
                  privilege is a real Unity Catalog privilege valid for that
                  object type, no duplicate object names, group names are used
                  consistently across the project.
3. WIRING       — every ``file(...)`` reference in a ``dbx_governance``
                  terragrunt.hcl resolves to a JSON file that exists (the
                  "easy to miss" step when adding a new domain).

Usage (CLI)::

    python scripts/validate_domains.py            # validate repo, exit 1 on error
    python scripts/validate_domains.py --strict    # warnings also fail
    python scripts/validate_domains.py --root /path/to/repo

Usage (importable)::

    from validate_domains import validate_repo
    findings = validate_repo(repo_root)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path

# --------------------------------------------------------------------------- #
# Unity Catalog privilege model
#
# Sourced from the Databricks UC privilege reference. We keep one allow-set per
# securable type that the JSON can grant on. A privilege used in the config that
# is not in the relevant set is almost always a typo (e.g. "READ_FILE" instead
# of "READ_FILES") and would surface as an opaque provider error at apply time.
# --------------------------------------------------------------------------- #

EXTERNAL_LOCATION_PRIVILEGES = frozenset(
    {
        "ALL_PRIVILEGES",
        "BROWSE",
        "CREATE_EXTERNAL_TABLE",
        "CREATE_EXTERNAL_VOLUME",
        "CREATE_FOREIGN_SECURABLE",
        "CREATE_MANAGED_STORAGE",
        "MANAGE",
        "READ_FILES",
        "WRITE_FILES",
    }
)

CATALOG_PRIVILEGES = frozenset(
    {
        "ALL_PRIVILEGES",
        "APPLY_TAG",
        "BROWSE",
        "CREATE_CONNECTION",
        "CREATE_FOREIGN_CATALOG",
        "CREATE_FOREIGN_SECURABLE",
        "CREATE_FUNCTION",
        "CREATE_MATERIALIZED_VIEW",
        "CREATE_MODEL",
        "CREATE_SCHEMA",
        "CREATE_TABLE",
        "CREATE_VOLUME",
        "EXECUTE",
        "EXTERNAL_USE_SCHEMA",
        "MANAGE",
        "MODIFY",
        "READ_VOLUME",
        "REFRESH",
        "SELECT",
        "USE_CATALOG",
        "USE_SCHEMA",
        "WRITE_VOLUME",
    }
)

SCHEMA_PRIVILEGES = frozenset(
    {
        "ALL_PRIVILEGES",
        "APPLY_TAG",
        "BROWSE",
        "CREATE_FUNCTION",
        "CREATE_MATERIALIZED_VIEW",
        "CREATE_MODEL",
        "CREATE_TABLE",
        "CREATE_VOLUME",
        "EXECUTE",
        "EXTERNAL_USE_SCHEMA",
        "MANAGE",
        "MODIFY",
        "READ_VOLUME",
        "REFRESH",
        "SELECT",
        "USE_SCHEMA",
        "WRITE_VOLUME",
    }
)

VOLUME_PRIVILEGES = frozenset(
    {
        "ALL_PRIVILEGES",
        "APPLY_TAG",
        "BROWSE",
        "MANAGE",
        "READ_VOLUME",
        "WRITE_VOLUME",
    }
)

# The HCL filters catalogs with an EXACT, case-sensitive string match:
#   managed = [for c in catalogs : c if c.type == "MANAGED"]
# so "Managed" / "managed" / "FEDERATED " silently vanish. Only these two
# literals are real.
VALID_CATALOG_TYPES = ("MANAGED", "FEDERATED")

ERROR = "ERROR"
WARNING = "WARNING"


@dataclass
class Finding:
    """A single validation result."""

    severity: str
    code: str
    message: str
    location: str = ""

    def __str__(self) -> str:
        where = f" [{self.location}]" if self.location else ""
        return f"{self.severity:7} {self.code}: {self.message}{where}"


@dataclass
class InfraIndex:
    """The set of objects an infra file declares — what grants may reference."""

    domain: str
    external_locations: set[str] = field(default_factory=set)
    catalogs: set[str] = field(default_factory=set)
    catalog_types: dict[str, str] = field(default_factory=dict)
    # fully-qualified "catalog.schema"
    schemas: set[str] = field(default_factory=set)
    # fully-qualified "catalog.schema.volume"
    volumes: set[str] = field(default_factory=set)


# --------------------------------------------------------------------------- #
# Low-level helpers
# --------------------------------------------------------------------------- #


def _rel(repo_root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def load_json(path: Path) -> tuple[object | None, Finding | None]:
    """Parse a JSON file. Returns (data, None) or (None, parse-error finding)."""
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh), None
    except FileNotFoundError:
        return None, Finding(ERROR, "FILE_MISSING", f"file does not exist: {path}", str(path))
    except json.JSONDecodeError as exc:
        return None, Finding(
            ERROR,
            "JSON_PARSE",
            f"invalid JSON: {exc.msg} (line {exc.lineno}, col {exc.colno})",
            str(path),
        )


def _is_str(value: object) -> bool:
    return isinstance(value, str) and value.strip() != ""


# --------------------------------------------------------------------------- #
# SCHEMA + index — infra files
# --------------------------------------------------------------------------- #


def build_infra_index(infra: dict, loc: str, findings: list[Finding]) -> InfraIndex:
    """Validate an infra file's schema and build the index of declared objects.

    Mirrors the structure the HCL/Terraform actually consume:
      external_locations[].location_name
      catalogs[].catalog_name / .type / .schemas[].schema_name / .volumes[].volume_name
    """
    idx = InfraIndex(domain=str(infra.get("domain", "?")))

    for key in ("cloud", "domain"):
        if not _is_str(infra.get(key)):
            findings.append(Finding(ERROR, "INFRA_FIELD", f"missing/empty top-level '{key}'", loc))

    # ---- external locations -------------------------------------------------
    ext_locs = infra.get("external_locations", [])
    if not isinstance(ext_locs, list):
        findings.append(Finding(ERROR, "INFRA_SHAPE", "'external_locations' must be a list", loc))
        ext_locs = []
    for el in ext_locs:
        if not isinstance(el, dict) or not _is_str(el.get("location_name")):
            findings.append(Finding(ERROR, "INFRA_EXT_LOC", "external location missing 'location_name'", loc))
            continue
        name = el["location_name"]
        if not _is_str(el.get("path")):
            findings.append(Finding(ERROR, "INFRA_EXT_LOC", f"external location '{name}' missing 'path'", loc))
        if name in idx.external_locations:
            findings.append(Finding(ERROR, "DUP_EXT_LOC", f"duplicate external location name '{name}'", loc))
        idx.external_locations.add(name)

    # ---- catalogs / schemas / volumes --------------------------------------
    catalogs = infra.get("catalogs", [])
    if not isinstance(catalogs, list):
        findings.append(Finding(ERROR, "INFRA_SHAPE", "'catalogs' must be a list", loc))
        catalogs = []

    for cat in catalogs:
        if not isinstance(cat, dict) or not _is_str(cat.get("catalog_name")):
            findings.append(Finding(ERROR, "INFRA_CATALOG", "catalog missing 'catalog_name'", loc))
            continue
        cname = cat["catalog_name"]
        if cname in idx.catalogs:
            findings.append(Finding(ERROR, "DUP_CATALOG", f"duplicate catalog name '{cname}'", loc))
        idx.catalogs.add(cname)

        ctype = cat.get("type")
        idx.catalog_types[cname] = ctype if isinstance(ctype, str) else ""
        if ctype not in VALID_CATALOG_TYPES:
            # Case-sensitive: a mis-cased value is dropped by the HCL MANAGED
            # filter and the catalog silently never gets created.
            findings.append(
                Finding(
                    ERROR,
                    "CATALOG_TYPE",
                    f"catalog '{cname}' has type {ctype!r}; must be exactly one of {VALID_CATALOG_TYPES} (case-sensitive)",
                    loc,
                )
            )
        if ctype == "FEDERATED" and not _is_str(cat.get("connection_name")):
            findings.append(
                Finding(
                    ERROR,
                    "CATALOG_FED",
                    f"federated catalog '{cname}' missing 'connection_name'",
                    loc,
                )
            )

        schemas = cat.get("schemas", [])
        if not isinstance(schemas, list):
            findings.append(Finding(ERROR, "INFRA_SHAPE", f"catalog '{cname}' schemas must be a list", loc))
            schemas = []
        seen_schemas: set[str] = set()
        for sch in schemas:
            if not isinstance(sch, dict) or not _is_str(sch.get("schema_name")):
                findings.append(Finding(ERROR, "INFRA_SCHEMA", f"catalog '{cname}' has a schema missing 'schema_name'", loc))
                continue
            sname = sch["schema_name"]
            fqsn = f"{cname}.{sname}"
            if sname in seen_schemas:
                findings.append(Finding(ERROR, "DUP_SCHEMA", f"duplicate schema name '{fqsn}'", loc))
            seen_schemas.add(sname)
            idx.schemas.add(fqsn)

            volumes = sch.get("volumes", [])
            if not isinstance(volumes, list):
                findings.append(Finding(ERROR, "INFRA_SHAPE", f"schema '{fqsn}' volumes must be a list", loc))
                volumes = []
            seen_volumes: set[str] = set()
            for vol in volumes:
                if not isinstance(vol, dict) or not _is_str(vol.get("volume_name")):
                    findings.append(Finding(ERROR, "INFRA_VOLUME", f"schema '{fqsn}' has a volume missing 'volume_name'", loc))
                    continue
                vname = vol["volume_name"]
                fqvn = f"{fqsn}.{vname}"
                if vname in seen_volumes:
                    findings.append(Finding(ERROR, "DUP_VOLUME", f"duplicate volume name '{fqvn}'", loc))
                seen_volumes.add(vname)
                idx.volumes.add(fqvn)
                # EXTERNAL volumes need a storage location to compute the URI.
                if vol.get("volume_type") == "EXTERNAL":
                    for vk in ("location_path", "volume_path"):
                        if not _is_str(vol.get(vk)):
                            findings.append(
                                Finding(
                                    ERROR,
                                    "INFRA_VOLUME",
                                    f"external volume '{fqvn}' missing '{vk}'",
                                    loc,
                                )
                            )

    return idx


# --------------------------------------------------------------------------- #
# SCHEMA + CONSISTENCY — grants files
# --------------------------------------------------------------------------- #


def _validate_grant_block(
    grants: object,
    object_label: str,
    valid_privileges: frozenset[str],
    loc: str,
    findings: list[Finding],
    principals: list[str],
) -> None:
    """Validate the inner ``grants: [{principal, privileges:[...]}]`` list."""
    if not isinstance(grants, list):
        findings.append(Finding(ERROR, "GRANT_SHAPE", f"{object_label}: 'grants' must be a list", loc))
        return
    for g in grants:
        if not isinstance(g, dict):
            findings.append(Finding(ERROR, "GRANT_SHAPE", f"{object_label}: grant entry must be an object", loc))
            continue
        principal = g.get("principal")
        if not _is_str(principal):
            findings.append(Finding(ERROR, "GRANT_PRINCIPAL", f"{object_label}: grant missing 'principal'", loc))
        else:
            principals.append(principal)
        privs = g.get("privileges")
        if not isinstance(privs, list) or not privs:
            findings.append(Finding(ERROR, "GRANT_PRIVS", f"{object_label}: grant for {principal!r} missing non-empty 'privileges'", loc))
            continue
        for p in privs:
            if not isinstance(p, str):
                findings.append(Finding(ERROR, "GRANT_PRIVS", f"{object_label}: privilege must be a string, got {p!r}", loc))
            elif p not in valid_privileges:
                findings.append(
                    Finding(
                        ERROR,
                        "PRIVILEGE_INVALID",
                        f"{object_label}: {p!r} is not a valid Unity Catalog privilege for this object type",
                        loc,
                    )
                )


def validate_grants(
    grants: dict,
    idx: InfraIndex,
    loc: str,
    findings: list[Finding],
    principals: list[str],
) -> None:
    """Validate a grants file: schema + cross-file existence against the infra index."""
    if not isinstance(grants, dict):
        findings.append(Finding(ERROR, "GRANT_SHAPE", "grants file must be a JSON object", loc))
        return

    # external_location_grants[].location_name  -> idx.external_locations
    for entry in grants.get("external_location_grants", []) or []:
        if not isinstance(entry, dict) or not _is_str(entry.get("location_name")):
            findings.append(Finding(ERROR, "GRANT_TARGET", "external_location_grant missing 'location_name'", loc))
            continue
        target = entry["location_name"]
        if target not in idx.external_locations:
            findings.append(
                Finding(
                    ERROR,
                    "DANGLING_GRANT",
                    f"grant references external location '{target}' not defined in infra",
                    loc,
                )
            )
        _validate_grant_block(entry.get("grants"), f"ext_loc '{target}'", EXTERNAL_LOCATION_PRIVILEGES, loc, findings, principals)

    # catalog_grants[].catalog_name -> idx.catalogs
    for entry in grants.get("catalog_grants", []) or []:
        if not isinstance(entry, dict) or not _is_str(entry.get("catalog_name")):
            findings.append(Finding(ERROR, "GRANT_TARGET", "catalog_grant missing 'catalog_name'", loc))
            continue
        target = entry["catalog_name"]
        if target not in idx.catalogs:
            findings.append(
                Finding(
                    ERROR,
                    "DANGLING_GRANT",
                    f"grant references catalog '{target}' not defined in infra",
                    loc,
                )
            )
        _validate_grant_block(entry.get("grants"), f"catalog '{target}'", CATALOG_PRIVILEGES, loc, findings, principals)

    # schema_grants[].schema = "catalog.schema" -> idx.schemas
    for entry in grants.get("schema_grants", []) or []:
        if not isinstance(entry, dict) or not _is_str(entry.get("schema")):
            findings.append(Finding(ERROR, "GRANT_TARGET", "schema_grant missing 'schema'", loc))
            continue
        target = entry["schema"]
        if target not in idx.schemas:
            findings.append(
                Finding(
                    ERROR,
                    "DANGLING_GRANT",
                    f"grant references schema '{target}' not defined in infra",
                    loc,
                )
            )
        _validate_grant_block(entry.get("grants"), f"schema '{target}'", SCHEMA_PRIVILEGES, loc, findings, principals)

    # volume_grants[].volume = "catalog.schema.volume" -> idx.volumes
    for entry in grants.get("volume_grants", []) or []:
        if not isinstance(entry, dict) or not _is_str(entry.get("volume")):
            findings.append(Finding(ERROR, "GRANT_TARGET", "volume_grant missing 'volume'", loc))
            continue
        target = entry["volume"]
        if target not in idx.volumes:
            findings.append(
                Finding(
                    ERROR,
                    "DANGLING_GRANT",
                    f"grant references volume '{target}' not defined in infra",
                    loc,
                )
            )
        _validate_grant_block(entry.get("grants"), f"volume '{target}'", VOLUME_PRIVILEGES, loc, findings, principals)


# --------------------------------------------------------------------------- #
# WIRING — terragrunt.hcl file() references
# --------------------------------------------------------------------------- #

_DOMAIN_PATH_RE = re.compile(r'domain_path\s*=\s*"([^"]*)"')
_FILE_REF_RE = re.compile(r'file\(\s*"([^"]*)"\s*\)')


def _resolve_interpolated_path(raw: str, tg_dir: Path, domain_path: str | None) -> Path | None:
    """Resolve a Terragrunt path string containing ${get_terragrunt_dir()} and
    ${local.domain_path}. Returns a normalised absolute Path, or None if it uses
    an interpolation we can't resolve offline."""
    resolved = raw
    if domain_path is not None:
        resolved = resolved.replace("${local.domain_path}", domain_path)
    resolved = resolved.replace("${get_terragrunt_dir()}", str(tg_dir))
    if "${" in resolved:  # unresolved interpolation — skip rather than guess
        return None
    if not os.path.isabs(resolved):
        resolved = str(tg_dir / resolved)
    return Path(os.path.normpath(resolved))


def find_governance_hcls(repo_root: Path) -> list[Path]:
    base = repo_root / "environments"
    return sorted(base.glob("**/data_platform/dbx_governance/terragrunt.hcl"))


def validate_wiring(repo_root: Path, findings: list[Finding]) -> set[Path]:
    """Check that every file(...) reference in each dbx_governance terragrunt.hcl
    points at a JSON file that exists. Returns the set of referenced JSON paths
    (used afterwards for the orphan check)."""
    repo_root = Path(repo_root).resolve()
    referenced: set[Path] = set()
    for hcl in find_governance_hcls(repo_root):
        text = hcl.read_text(encoding="utf-8")
        # Anchor to an absolute dir so ${get_terragrunt_dir()} / ${local.domain_path}
        # substitution stays correct regardless of whether repo_root was relative.
        tg_dir = hcl.resolve().parent
        loc = _rel(repo_root, hcl)

        dp_match = _DOMAIN_PATH_RE.search(text)
        domain_path = None
        if dp_match:
            dp = _resolve_interpolated_path(dp_match.group(1), tg_dir, None)
            domain_path = str(dp) if dp else None

        for raw in _FILE_REF_RE.findall(text):
            resolved = _resolve_interpolated_path(raw, tg_dir, domain_path)
            if resolved is None:
                continue
            referenced.add(resolved)
            if not resolved.is_file():
                findings.append(
                    Finding(
                        ERROR,
                        "WIRING_MISSING",
                        f"terragrunt file() reference points at a missing file: {_rel(repo_root, resolved)}",
                        loc,
                    )
                )
    return referenced


def validate_orphans(repo_root: Path, referenced: set[Path], findings: list[Finding]) -> None:
    """Flag domain JSON files that no terragrunt.hcl references (WARNING)."""
    domains_dir = repo_root / "environments" / "dev" / "domains"
    if not domains_dir.is_dir():
        return
    referenced_resolved = {p.resolve() for p in referenced}
    for jf in sorted(domains_dir.glob("**/*.json")):
        if jf.resolve() not in referenced_resolved:
            findings.append(
                Finding(
                    WARNING,
                    "ORPHAN_JSON",
                    f"domain JSON not referenced by any dbx_governance terragrunt.hcl: {_rel(repo_root, jf)}",
                    _rel(repo_root, jf),
                )
            )


# --------------------------------------------------------------------------- #
# CONSISTENCY — group naming across the whole project
# --------------------------------------------------------------------------- #


def validate_group_consistency(principal_counts: dict[str, int], findings: list[Finding]) -> None:
    """A group that appears only once across the entire project is a likely
    typo (e.g. 'data_enginers'). Emitted as WARNING — some singletons are
    legitimately scoped to one domain."""
    for principal, count in sorted(principal_counts.items()):
        if count == 1:
            findings.append(
                Finding(
                    WARNING,
                    "GROUP_SINGLETON",
                    f"group/principal '{principal}' is used only once across the project "
                    f"(likely a typo, or a legitimately single-use group)",
                )
            )


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #


def discover_domain_files(repo_root: Path) -> list[tuple[Path, Path]]:
    """Return (infra_path, grants_path) pairs found under domains/<cloud>/."""
    domains_dir = repo_root / "environments" / "dev" / "domains"
    pairs: list[tuple[Path, Path]] = []
    for infra in sorted(domains_dir.glob("**/*_infra.json")):
        grants = infra.with_name(infra.name.replace("_infra.json", "_grants.json"))
        pairs.append((infra, grants))
    return pairs


def validate_repo(repo_root: str | os.PathLike) -> list[Finding]:
    """Validate the whole repository. Returns a flat list of findings."""
    repo_root = Path(repo_root).resolve()
    findings: list[Finding] = []
    principal_counts: dict[str, int] = {}

    pairs = discover_domain_files(repo_root)
    if not pairs:
        findings.append(Finding(WARNING, "NO_DOMAINS", "no *_infra.json files found under environments/dev/domains", ""))

    for infra_path, grants_path in pairs:
        infra_loc = _rel(repo_root, infra_path)
        infra_data, err = load_json(infra_path)
        if err:
            findings.append(err)
            continue
        if not isinstance(infra_data, dict):
            findings.append(Finding(ERROR, "INFRA_SHAPE", "infra file must be a JSON object", infra_loc))
            continue
        idx = build_infra_index(infra_data, infra_loc, findings)

        grants_loc = _rel(repo_root, grants_path)
        grants_data, gerr = load_json(grants_path)
        if gerr:
            findings.append(gerr)
            continue
        local_principals: list[str] = []
        if isinstance(grants_data, dict):
            validate_grants(grants_data, idx, grants_loc, findings, local_principals)
        else:
            findings.append(Finding(ERROR, "GRANT_SHAPE", "grants file must be a JSON object", grants_loc))
        for p in local_principals:
            principal_counts[p] = principal_counts.get(p, 0) + 1

    validate_group_consistency(principal_counts, findings)

    referenced = validate_wiring(repo_root, findings)
    validate_orphans(repo_root, referenced, findings)

    return findings


# --------------------------------------------------------------------------- #
# Reporting helpers
# --------------------------------------------------------------------------- #


def count_by_severity(findings: Iterable[Finding]) -> dict[str, int]:
    out = {ERROR: 0, WARNING: 0}
    for f in findings:
        out[f.severity] = out.get(f.severity, 0) + 1
    return out


def has_errors(findings: Iterable[Finding]) -> bool:
    return any(f.severity == ERROR for f in findings)


def _default_repo_root() -> Path:
    # scripts/ lives at the repo root.
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate Databricks UC domain governance JSON config (offline).")
    parser.add_argument("--root", default=str(_default_repo_root()), help="repository root (default: parent of scripts/)")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    parser.add_argument("--quiet", action="store_true", help="only print the summary line")
    args = parser.parse_args(argv)

    findings = validate_repo(args.root)
    errors = [f for f in findings if f.severity == ERROR]
    warnings = [f for f in findings if f.severity == WARNING]

    if not args.quiet:
        for f in errors + warnings:
            print(f)
        if findings:
            print()

    counts = count_by_severity(findings)
    print(f"domain-config validation: {counts[ERROR]} error(s), {counts[WARNING]} warning(s)")

    failed = bool(errors) or (args.strict and bool(warnings))
    if failed:
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
