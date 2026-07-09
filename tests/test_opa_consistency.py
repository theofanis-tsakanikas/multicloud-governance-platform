"""Offline cross-check that the Rego policy (policy/opa/governance.rego) and the
Python analyzer agree. The three gating rules are re-implemented here in Python
and run over the same grounding pack the Rego policy consumes; this proves the
two engines would reach the same verdict even when the `conftest` binary is not
installed (CI runs the real conftest as well)."""

import json
from pathlib import Path

from policy_analyzer import run_analysis

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTEXT = REPO_ROOT / "docs" / "governance" / "governance_context.json"
VIOLATION = REPO_ROOT / "policy" / "opa" / "examples" / "violation_input.json"

PUBLIC = {"users", "account users", "all account users", "all users", "public", "*"}
ADMINS = {"metastore_admins"}
READ = {"SELECT", "READ_VOLUME", "READ_FILES"}
SENSITIVE = {"confidential", "pii"}


def _owner_index(ctx: dict) -> dict:
    return {o["name"]: o.get("owner") for o in ctx.get("objects", []) if o["object_type"] == "catalog"}


def _accepted(ctx: dict, rule: str, a: dict) -> bool:
    ref = f"{a['object_type']}:{a['object']}"
    return any(
        f["rule"] == rule and f.get("accepted") and f["object"] == ref and f["principal"] == a["principal"]
        for f in ctx.get("policy_findings", [])
    )


def rego_denials(ctx: dict) -> set[str]:
    """Python mirror of policy/opa/governance.rego — returns the set of denied rules×objects."""
    owners = _owner_index(ctx)
    denials: set[str] = set()
    for a in ctx.get("access_matrix", []):
        ref = f"{a['object_type']}:{a['object']}:{a['principal']}"
        privs = set(a.get("privileges", []))
        if a["principal"].lower() in PUBLIC and not _accepted(ctx, "PUBLIC_PRINCIPAL", a):
            denials.add(f"PUBLIC_PRINCIPAL:{ref}")
        if a.get("classification") == "pii" and a["principal"] not in ADMINS and (privs & READ) and not _accepted(ctx, "PII_BROAD_READ", a):
            denials.add(f"PII_BROAD_READ:{ref}")
        catalog = a["object"].split(".")[0]
        is_owner = owners.get(catalog) == a["principal"]
        if (
            a.get("classification") in SENSITIVE
            and "ALL_PRIVILEGES" in privs
            and a["principal"] not in ADMINS
            and not is_owner
            and not _accepted(ctx, "SENSITIVE_ALL_PRIVILEGES", a)
        ):
            denials.add(f"SENSITIVE_ALL_PRIVILEGES:{ref}")
    return denials


def test_clean_context_has_zero_denials():
    ctx = json.loads(CONTEXT.read_text(encoding="utf-8"))
    assert rego_denials(ctx) == set(), "Rego policy would deny the committed config — it must be clean"


def test_clean_context_matches_analyzer():
    # Both engines agree: no gating HIGH on the committed config.
    ctx = json.loads(CONTEXT.read_text(encoding="utf-8"))
    assert rego_denials(ctx) == set()
    assert run_analysis(REPO_ROOT).gating == []


def test_violation_fixture_trips_all_three_rules():
    ctx = json.loads(VIOLATION.read_text(encoding="utf-8"))
    denied_rules = {d.split(":", 1)[0] for d in rego_denials(ctx)}
    assert denied_rules == {"PUBLIC_PRINCIPAL", "PII_BROAD_READ", "SENSITIVE_ALL_PRIVILEGES"}
