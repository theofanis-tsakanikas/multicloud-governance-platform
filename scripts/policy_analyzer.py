#!/usr/bin/env python3
"""Deterministic Unity Catalog access-policy analyzer — the governance trust core.

This is the **source of truth** for whether the platform's access model is safe.
It is intentionally rule-based and credential-free: every finding is reproducible
from the committed JSON, with no LLM in the decision path. The optional Genie
layer (``genie_space.py``) sits *on top* of this as a read-only convenience —
it never decides anything this module hasn't already proven.

Maps directly onto the Responsible-AI Readiness Framework, dimension 4
(*Governance as code: accountability must be provable on demand, not promised in
a PDF*) and dimension 1 (*sensitive fields classified and handled at the data
layer*).

## What it checks

Over the flattened :class:`GovernanceModel`, it applies least-privilege and
data-protection rules:

| Rule                     | Sev    | Concern                                              |
| ------------------------ | ------ | --------------------------------------------------- |
| PUBLIC_PRINCIPAL         | HIGH   | data granted to an all-users / public principal     |
| PII_BROAD_READ           | HIGH   | PII readable by a principal not on the allowlist    |
| PII_WRITE                | HIGH   | PII writable/modifiable by a non-admin principal    |
| SENSITIVE_ALL_PRIVILEGES | HIGH   | ALL_PRIVILEGES on confidential/PII data (non-admin) |
| MANAGE_NONADMIN          | MEDIUM | MANAGE (can alter grants) held by a non-admin       |
| ALL_PRIVILEGES_NONADMIN  | MEDIUM | ALL_PRIVILEGES sprawl beyond admins/owners          |
| UNCLASSIFIED_SCHEMA      | LOW    | schema with no data classification (hygiene)        |
| UNOWNED_CATALOG          | LOW    | catalog with no accountable owner                   |
| FEDERATED_PII            | INFO   | PII residing in federated (non-UC-managed) storage  |

## Exceptions (governance-as-code)

Intentional deviations are not silenced in code — they are declared in
``environments/dev/policy_exceptions.json`` with a justification, an approver,
and an expiry. A matching, **unexpired** exception downgrades a finding to an
*accepted risk* (reported, but not gating). An expired exception stops
suppressing — the risk re-surfaces for re-review. This is the auditable
who/what/why/until that a regulator can be handed.

## CI gate

Exit code is non-zero when any **unacknowledged HIGH** finding exists (or, with
``--strict``, any unacknowledged MEDIUM). Wire it after ``validate_domains`` in
the offline config-validation workflow.

Usage::

    python scripts/policy_analyzer.py                 # human report, gate on HIGH
    python scripts/policy_analyzer.py --strict        # gate on MEDIUM too
    python scripts/policy_analyzer.py --format json    # machine-readable findings
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import sys
from collections.abc import Iterable
from dataclasses import asdict, dataclass, field
from pathlib import Path

from governance_model import (
    ADMIN_PRIVILEGES,
    DATA_READ_PRIVILEGES,
    WRITE_PRIVILEGES,
    GovernanceModel,
    Grant,
    build_model,
    is_sensitive,
)

# --------------------------------------------------------------------------- #
# Policy configuration (sensible defaults; overridable per engagement)
# --------------------------------------------------------------------------- #

# Principals with platform-admin authority — exempt from least-privilege rules.
DEFAULT_ADMIN_PRINCIPALS = frozenset({"metastore_admins"})

# Principals that mean "everyone" — granting data to these is a HIGH finding.
PUBLIC_PRINCIPALS = frozenset({"users", "account users", "all account users", "all users", "public", "*"})

HIGH, MEDIUM, LOW, INFO = "HIGH", "MEDIUM", "LOW", "INFO"
_SEVERITY_ORDER = {HIGH: 0, MEDIUM: 1, LOW: 2, INFO: 3}

# Responsible-AI Readiness Framework dimension each rule evidences.
_DIMENSION = {
    "PUBLIC_PRINCIPAL": "Governance as code",
    "PII_BROAD_READ": "Data quality & lineage",
    "PII_WRITE": "Data quality & lineage",
    "SENSITIVE_ALL_PRIVILEGES": "Governance as code",
    "MANAGE_NONADMIN": "Governance as code",
    "ALL_PRIVILEGES_NONADMIN": "Governance as code",
    "UNCLASSIFIED_SCHEMA": "Data quality & lineage",
    "UNOWNED_CATALOG": "Governance as code",
    "FEDERATED_PII": "Data quality & lineage",
}


@dataclass
class PolicyFinding:
    """One policy observation about a grant or securable."""

    rule: str
    severity: str
    cloud: str
    object_ref: str  # "schema:catalog.schema" etc.
    principal: str  # "" for object-level findings (e.g. unclassified schema)
    message: str
    remediation: str
    dimension: str = ""
    accepted: bool = False  # suppressed by an unexpired exception
    justification: str = ""  # populated when accepted

    def key(self) -> tuple[str, str, str]:
        return (self.rule, self.object_ref, self.principal)

    def __str__(self) -> str:
        tag = "ACCEPTED" if self.accepted else self.severity
        who = f" → {self.principal}" if self.principal else ""
        return f"{tag:8} {self.rule}: [{self.cloud}] {self.object_ref}{who} — {self.message}"


# --------------------------------------------------------------------------- #
# Exceptions
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Exception_:
    rule: str
    object_ref: str
    principal: str
    justification: str
    approved_by: str
    expires: str  # ISO date; "" = no expiry

    def is_expired(self, today: _dt.date) -> bool:
        if not self.expires:
            return False
        try:
            return _dt.date.fromisoformat(self.expires) < today
        except ValueError:
            return False  # malformed expiry → treat as non-expiring, surfaced elsewhere


def load_exceptions(path: Path) -> list[Exception_]:
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    out: list[Exception_] = []
    for e in data.get("exceptions", []) or []:
        if not isinstance(e, dict):
            continue
        out.append(
            Exception_(
                rule=str(e.get("rule", "")),
                object_ref=str(e.get("object", "")),
                principal=str(e.get("principal", "")),
                justification=str(e.get("justification", "")),
                approved_by=str(e.get("approved_by", "")),
                expires=str(e.get("expires", "")),
            )
        )
    return out


# --------------------------------------------------------------------------- #
# Rules
# --------------------------------------------------------------------------- #


def _ref(g: Grant) -> str:
    return f"{g.object_type}:{g.fqn}"


def _is_admin(principal: str, admins: frozenset[str]) -> bool:
    return principal in admins


def analyze(
    model: GovernanceModel,
    *,
    admins: frozenset[str] = DEFAULT_ADMIN_PRINCIPALS,
) -> list[PolicyFinding]:
    """Run every rule over the model and return raw findings (pre-exceptions)."""
    findings: list[PolicyFinding] = []

    # Owner lookup: catalog-name → owner principal (owners may hold broad rights
    # on objects within their own catalog without tripping sprawl rules).
    owner_of: dict[str, str | None] = {}
    for s in model.securables:
        if s.object_type == "catalog":
            owner_of[s.fqn] = s.owner

    def catalog_of(fqn: str) -> str:
        return fqn.split(".", 1)[0]

    # ---- grant-level rules ------------------------------------------------ #
    for g in model.grants:
        ref = _ref(g)
        privs = set(g.privileges)
        principal_lc = g.principal.lower()
        is_admin = _is_admin(g.principal, admins)
        owner = owner_of.get(catalog_of(g.fqn))
        is_owner = owner is not None and g.principal == owner

        # 1. Public principal anywhere.
        if principal_lc in PUBLIC_PRINCIPALS:
            findings.append(
                PolicyFinding(
                    "PUBLIC_PRINCIPAL",
                    HIGH,
                    g.cloud,
                    ref,
                    g.principal,
                    "data is granted to an all-users / public principal",
                    "Replace the public principal with a named least-privilege group.",
                    _DIMENSION["PUBLIC_PRINCIPAL"],
                )
            )

        if g.classification == "pii" and not is_admin:
            # 2. PII readable by a non-admin (allowlist enforced via exceptions).
            if privs & DATA_READ_PRIVILEGES:
                findings.append(
                    PolicyFinding(
                        "PII_BROAD_READ",
                        HIGH,
                        g.cloud,
                        ref,
                        g.principal,
                        "PII is readable by a non-admin principal not on the PII allowlist",
                        "Restrict to an explicit allowlist, or declare a reviewed exception with a DPIA reference.",
                        _DIMENSION["PII_BROAD_READ"],
                    )
                )
            # 3. PII writable/modifiable by a non-admin.
            if privs & (WRITE_PRIVILEGES | {"ALL_PRIVILEGES"}):
                findings.append(
                    PolicyFinding(
                        "PII_WRITE",
                        HIGH,
                        g.cloud,
                        ref,
                        g.principal,
                        "PII is writable/modifiable by a non-admin principal",
                        "Remove write/ALL_PRIVILEGES on PII from non-admin principals.",
                        _DIMENSION["PII_WRITE"],
                    )
                )

        # 4. ALL_PRIVILEGES on sensitive (confidential/PII) data, non-admin/non-owner.
        if "ALL_PRIVILEGES" in privs and is_sensitive(g.classification) and not is_admin and not is_owner:
            findings.append(
                PolicyFinding(
                    "SENSITIVE_ALL_PRIVILEGES",
                    HIGH,
                    g.cloud,
                    ref,
                    g.principal,
                    f"ALL_PRIVILEGES granted on {g.classification} data to a non-admin, non-owner principal",
                    "Grant only the specific privileges required (e.g. SELECT, USE_SCHEMA).",
                    _DIMENSION["SENSITIVE_ALL_PRIVILEGES"],
                )
            )

        # 5. MANAGE held by a non-admin (can re-grant access = escalation).
        if "MANAGE" in privs and not is_admin and not is_owner:
            findings.append(
                PolicyFinding(
                    "MANAGE_NONADMIN",
                    MEDIUM,
                    g.cloud,
                    ref,
                    g.principal,
                    "MANAGE (the right to alter grants) is held by a non-admin principal",
                    "Reserve MANAGE for the admin group or the object owner.",
                    _DIMENSION["MANAGE_NONADMIN"],
                )
            )

        # 6. ALL_PRIVILEGES sprawl beyond admins/owners (any object).
        if "ALL_PRIVILEGES" in privs and not is_admin and not is_owner and "ALL_PRIVILEGES" not in (ADMIN_PRIVILEGES - privs):
            # (the last clause is always true; kept explicit for readability)
            if not is_sensitive(g.classification):  # sensitive ones already covered as HIGH above
                findings.append(
                    PolicyFinding(
                        "ALL_PRIVILEGES_NONADMIN",
                        MEDIUM,
                        g.cloud,
                        ref,
                        g.principal,
                        "ALL_PRIVILEGES granted to a non-admin, non-owner principal",
                        "Confirm the principal truly needs full control; otherwise scope down to explicit privileges.",
                        _DIMENSION["ALL_PRIVILEGES_NONADMIN"],
                    )
                )

    # ---- object-level rules ----------------------------------------------- #
    for s in model.securables:
        if s.object_type == "schema" and s.classification is None:
            findings.append(
                PolicyFinding(
                    "UNCLASSIFIED_SCHEMA",
                    LOW,
                    s.cloud,
                    f"schema:{s.fqn}",
                    "",
                    "schema has no data classification — it cannot be protected by classification-aware policy",
                    "Add a 'classification' (public|internal|confidential|pii) to the schema in its *_infra.json.",
                    _DIMENSION["UNCLASSIFIED_SCHEMA"],
                )
            )
        if s.object_type == "catalog" and not s.owner:
            findings.append(
                PolicyFinding(
                    "UNOWNED_CATALOG",
                    LOW,
                    s.cloud,
                    f"catalog:{s.fqn}",
                    "",
                    "catalog has no accountable owner",
                    "Add an 'owner' group to the catalog in its *_infra.json.",
                    _DIMENSION["UNOWNED_CATALOG"],
                )
            )
        if s.object_type == "schema" and s.classification == "pii" and s.catalog_type == "FEDERATED":
            findings.append(
                PolicyFinding(
                    "FEDERATED_PII",
                    INFO,
                    s.cloud,
                    f"schema:{s.fqn}",
                    "",
                    "PII resides in a federated source (outside Unity Catalog managed storage)",
                    "Confirm data-residency and retention are governed at the source; lineage crosses a trust boundary.",
                    _DIMENSION["FEDERATED_PII"],
                )
            )

    findings.sort(key=lambda f: (_SEVERITY_ORDER.get(f.severity, 9), f.rule, f.cloud, f.object_ref, f.principal))
    return findings


def apply_exceptions(
    findings: list[PolicyFinding],
    exceptions: Iterable[Exception_],
    *,
    today: _dt.date | None = None,
) -> list[PolicyFinding]:
    """Mark findings accepted where an unexpired exception matches (rule, object, principal)."""
    today = today or _dt.date.today()
    active = {(e.rule, e.object_ref, e.principal): e for e in exceptions if not e.is_expired(today)}
    for f in findings:
        match = active.get(f.key())
        if match:
            f.accepted = True
            f.justification = match.justification
    return findings


# --------------------------------------------------------------------------- #
# Orchestration + reporting
# --------------------------------------------------------------------------- #


@dataclass
class AnalysisResult:
    findings: list[PolicyFinding] = field(default_factory=list)

    @property
    def gating(self) -> list[PolicyFinding]:
        """Unacknowledged HIGH findings — these fail CI."""
        return [f for f in self.findings if f.severity == HIGH and not f.accepted]

    @property
    def medium_open(self) -> list[PolicyFinding]:
        return [f for f in self.findings if f.severity == MEDIUM and not f.accepted]

    @property
    def accepted(self) -> list[PolicyFinding]:
        return [f for f in self.findings if f.accepted]

    def counts(self) -> dict[str, int]:
        out = {HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0, "ACCEPTED": 0}
        for f in self.findings:
            if f.accepted:
                out["ACCEPTED"] += 1
            else:
                out[f.severity] = out.get(f.severity, 0) + 1
        return out


def run_analysis(repo_root: str | Path, exceptions_path: Path | None = None) -> AnalysisResult:
    repo_root = Path(repo_root).resolve()
    model = build_model(repo_root)
    findings = analyze(model)
    exc_path = exceptions_path or (repo_root / "environments" / "dev" / "policy_exceptions.json")
    apply_exceptions(findings, load_exceptions(exc_path))
    return AnalysisResult(findings)


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze Databricks UC access policy (offline, deterministic).")
    parser.add_argument("--root", default=str(_default_repo_root()), help="repository root (default: parent of scripts/)")
    parser.add_argument("--strict", action="store_true", help="also fail on unacknowledged MEDIUM findings")
    parser.add_argument("--format", choices=("text", "json"), default="text", help="output format")
    parser.add_argument("--exceptions", default=None, help="path to policy_exceptions.json")
    args = parser.parse_args(argv)

    exc_path = Path(args.exceptions) if args.exceptions else None
    result = run_analysis(args.root, exc_path)

    if args.format == "json":
        print(json.dumps([asdict(f) for f in result.findings], indent=2))
    else:
        for f in result.findings:
            print(f)
        if result.findings:
            print()
        c = result.counts()
        print(
            f"policy scan: {c[HIGH]} high, {c[MEDIUM]} medium, {c[LOW]} low, "
            f"{c[INFO]} info, {c['ACCEPTED']} accepted (documented exceptions)"
        )

    failed = bool(result.gating) or (args.strict and bool(result.medium_open))
    if failed:
        if args.format == "text":
            print("RESULT: FAIL — unacknowledged policy violations block deployment.")
        return 1
    if args.format == "text":
        print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
