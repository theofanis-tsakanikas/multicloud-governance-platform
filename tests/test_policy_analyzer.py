"""Tests for policy_analyzer: the deterministic least-privilege / PII gate."""

import datetime as dt
import json
from pathlib import Path

from governance_model import GovernanceModel, Grant, Securable
from policy_analyzer import (
    Exception_,
    analyze,
    apply_exceptions,
    load_exceptions,
    run_analysis,
)

REPO_ROOT = Path(__file__).resolve().parent.parent


def _model(securables, grants) -> GovernanceModel:
    return GovernanceModel(securables=securables, grants=grants)


def _pii_schema(fqn="c.s", catalog_type="MANAGED"):
    return Securable("AWS", "d", "schema", fqn, classification="pii", catalog_type=catalog_type)


def _grant(principal, privileges, fqn="c.s", classification="pii", object_type="schema"):
    return Grant("AWS", "d", object_type, fqn, principal, tuple(privileges), classification=classification)


# --------------------------------------------------------------------------- #
# individual rules
# --------------------------------------------------------------------------- #


def test_pii_broad_read_flagged_high():
    m = _model([_pii_schema()], [_grant("analysts", ["USE_SCHEMA", "SELECT"])])
    findings = analyze(m)
    rules = {f.rule: f for f in findings}
    assert "PII_BROAD_READ" in rules
    assert rules["PII_BROAD_READ"].severity == "HIGH"


def test_pii_read_by_admin_is_exempt():
    m = _model([_pii_schema()], [_grant("metastore_admins", ["ALL_PRIVILEGES"])])
    findings = analyze(m)
    assert not [f for f in findings if f.rule in ("PII_BROAD_READ", "PII_WRITE")]


def test_pii_write_flagged_high():
    m = _model([_pii_schema()], [_grant("analysts", ["MODIFY"])])
    findings = analyze(m)
    assert any(f.rule == "PII_WRITE" and f.severity == "HIGH" for f in findings)


def test_public_principal_flagged_high():
    m = _model(
        [Securable("AWS", "d", "schema", "c.s", classification="internal")],
        [_grant("account users", ["SELECT"], classification="internal")],
    )
    findings = analyze(m)
    assert any(f.rule == "PUBLIC_PRINCIPAL" and f.severity == "HIGH" for f in findings)


def test_sensitive_all_privileges_flagged_high():
    m = _model(
        [Securable("AWS", "d", "schema", "c.s", classification="confidential")],
        [_grant("analysts", ["ALL_PRIVILEGES"], classification="confidential")],
    )
    findings = analyze(m)
    assert any(f.rule == "SENSITIVE_ALL_PRIVILEGES" and f.severity == "HIGH" for f in findings)


def test_all_privileges_nonadmin_on_nonsensitive_is_medium():
    m = _model(
        [Securable("AWS", "d", "external_location", "loc", classification=None)],
        [_grant("data_engineers", ["ALL_PRIVILEGES"], fqn="loc", classification=None, object_type="external_location")],
    )
    findings = analyze(m)
    assert any(f.rule == "ALL_PRIVILEGES_NONADMIN" and f.severity == "MEDIUM" for f in findings)


def test_owner_exempt_from_all_privileges_sprawl():
    cat = Securable("AWS", "d", "catalog", "c", owner="data_engineers")
    sch = Securable("AWS", "d", "schema", "c.s", classification="internal")
    g = _grant("data_engineers", ["ALL_PRIVILEGES"], classification="internal")
    findings = analyze(_model([cat, sch], [g]))
    assert not [f for f in findings if f.rule == "ALL_PRIVILEGES_NONADMIN"]


def test_unclassified_schema_low():
    m = _model([Securable("AWS", "d", "schema", "c.s", classification=None)], [])
    findings = analyze(m)
    assert any(f.rule == "UNCLASSIFIED_SCHEMA" and f.severity == "LOW" for f in findings)


def test_unowned_catalog_low():
    m = _model([Securable("AWS", "d", "catalog", "c", owner=None)], [])
    findings = analyze(m)
    assert any(f.rule == "UNOWNED_CATALOG" and f.severity == "LOW" for f in findings)


def test_federated_pii_info():
    m = _model([_pii_schema(catalog_type="FEDERATED")], [])
    findings = analyze(m)
    assert any(f.rule == "FEDERATED_PII" and f.severity == "INFO" for f in findings)


# --------------------------------------------------------------------------- #
# exceptions
# --------------------------------------------------------------------------- #


def test_unexpired_exception_downgrades_high():
    m = _model([_pii_schema()], [_grant("analysts", ["SELECT"])])
    findings = analyze(m)
    exc = Exception_("PII_BROAD_READ", "schema:c.s", "analysts", "j", "dpo", "2999-01-01")
    apply_exceptions(findings, [exc], today=dt.date(2026, 1, 1))
    pii = [f for f in findings if f.rule == "PII_BROAD_READ"][0]
    assert pii.accepted is True
    assert pii.justification == "j"


def test_expired_exception_does_not_suppress():
    m = _model([_pii_schema()], [_grant("analysts", ["SELECT"])])
    findings = analyze(m)
    exc = Exception_("PII_BROAD_READ", "schema:c.s", "analysts", "j", "dpo", "2020-01-01")
    apply_exceptions(findings, [exc], today=dt.date(2026, 1, 1))
    pii = [f for f in findings if f.rule == "PII_BROAD_READ"][0]
    assert pii.accepted is False


def test_load_exceptions_file(tmp_path):
    p = tmp_path / "exc.json"
    p.write_text(json.dumps({"exceptions": [{"rule": "R", "object": "o", "principal": "p", "expires": "2030-01-01"}]}))
    exceptions = load_exceptions(p)
    assert len(exceptions) == 1 and exceptions[0].rule == "R"


def test_load_exceptions_missing_file_is_empty(tmp_path):
    assert load_exceptions(tmp_path / "nope.json") == []


# --------------------------------------------------------------------------- #
# end-to-end on the real repo (the committed config must be clean)
# --------------------------------------------------------------------------- #


def test_real_repo_has_no_unacknowledged_high():
    result = run_analysis(REPO_ROOT)
    assert result.gating == [], f"unacknowledged HIGH findings: {[str(f) for f in result.gating]}"


def test_real_repo_documents_pii_exceptions():
    result = run_analysis(REPO_ROOT)
    accepted_rules = {f.rule for f in result.accepted}
    assert "PII_BROAD_READ" in accepted_rules


def test_gate_trips_on_injected_violation(tmp_path):
    # A fresh PII read with NO exception must produce an unacknowledged HIGH.
    infra = {
        "cloud": "AWS",
        "domain": "x",
        "catalogs": [{"catalog_name": "c", "type": "MANAGED", "schemas": [{"schema_name": "s", "classification": "pii"}]}],
    }
    grants = {"schema_grants": [{"schema": "c.s", "grants": [{"principal": "business_users", "privileges": ["SELECT"]}]}]}
    d = tmp_path / "environments" / "dev" / "domains" / "aws"
    d.mkdir(parents=True)
    (d / "x_infra.json").write_text(json.dumps(infra))
    (d / "x_grants.json").write_text(json.dumps(grants))
    result = run_analysis(tmp_path)
    assert any(f.rule == "PII_BROAD_READ" and not f.accepted for f in result.gating)


def test_malformed_expiry_fails_closed():
    # The hole this guards: a typo in an exception's `expires` used to be treated as "never
    # expires", so it suppressed a gating HIGH forever, silently. A malformed date must fail CLOSED
    # — treated as already expired, so the finding it covers re-surfaces and the gate goes red.
    today = dt.date(2026, 7, 13)

    def _exc(expires):
        return Exception_("PII_BROAD_READ", "schema:c.s", "analysts", "j", "a", expires)

    assert _exc("2025-01-01").is_expired(today)  # well-formed past date → expired
    assert not _exc("2099-01-01").is_expired(today)  # well-formed future date → not expired
    assert not _exc("").is_expired(today)  # no expiry declared → never expires
    for bad in ("2025/12/31", "31-12-2025", "2025-13-01", "not-a-date"):
        assert _exc(bad).is_expired(today), f"malformed {bad!r} must fail closed (be treated as expired)"


def test_malformed_expiry_does_not_suppress_finding():
    # End-to-end: an exception whose date is malformed must NOT downgrade its finding to accepted.
    m = _model([_pii_schema("c.s")], [_grant("analysts", ["USE_SCHEMA", "SELECT"], fqn="c.s")])
    rule, obj, principal = next(f for f in analyze(m) if f.rule == "PII_BROAD_READ").key()
    today = dt.date(2026, 7, 13)

    def _exc(expires):
        return Exception_(rule, obj, principal, "j", "a", expires)

    # Control: a well-formed FUTURE expiry does suppress — proves the exception key matches the
    # finding, so the malformed case below fails for the right reason.
    good = apply_exceptions(analyze(m), [_exc("2099-01-01")], today=today)
    assert next(f for f in good if f.rule == "PII_BROAD_READ").accepted
    # The fix: a malformed expiry must NOT suppress — it fails closed.
    bad = apply_exceptions(analyze(m), [_exc("2025/12/31")], today=today)
    assert not next(f for f in bad if f.rule == "PII_BROAD_READ").accepted
