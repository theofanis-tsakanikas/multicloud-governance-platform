"""Tests for the policy_analyzer reporting surfaces: SARIF + expiry warnings."""

import datetime as dt
from pathlib import Path

from governance_model import GovernanceModel, Grant, Securable
from policy_analyzer import (
    AnalysisResult,
    Exception_,
    analyze,
    expiring_exceptions,
    to_sarif,
)

REPO_ROOT = Path(__file__).resolve().parent.parent


def _pii_model():
    return GovernanceModel(
        securables=[Securable("AWS", "d", "schema", "c.s", classification="pii")],
        grants=[Grant("AWS", "d", "schema", "c.s", "analysts", ("SELECT",), classification="pii")],
    )


# ---- SARIF ---------------------------------------------------------------- #


def test_sarif_is_valid_2_1_0_shape():
    result = AnalysisResult(analyze(_pii_model()))
    sarif = to_sarif(result, REPO_ROOT)
    assert sarif["version"] == "2.1.0"
    run = sarif["runs"][0]
    assert run["tool"]["driver"]["name"] == "uc-policy-analyzer"
    assert len(run["results"]) == len(result.findings)
    # every result carries a ruleId, a level, and a navigable location
    for r in run["results"]:
        assert r["ruleId"]
        assert r["level"] in ("error", "warning", "note")
        assert r["locations"][0]["physicalLocation"]["artifactLocation"]["uri"]


def test_sarif_high_is_error_level():
    result = AnalysisResult(analyze(_pii_model()))
    sarif = to_sarif(result, REPO_ROOT)
    pii = [r for r in sarif["runs"][0]["results"] if r["ruleId"] == "PII_BROAD_READ"][0]
    assert pii["level"] == "error"


def test_sarif_accepted_finding_is_suppressed():
    findings = analyze(_pii_model())
    findings[0].accepted = True
    findings[0].justification = "DPIA-1"
    sarif = to_sarif(AnalysisResult(findings), REPO_ROOT)
    accepted = [r for r in sarif["runs"][0]["results"] if r.get("suppressions")]
    assert accepted and accepted[0]["suppressions"][0]["justification"] == "DPIA-1"


def test_real_repo_sarif_serializable():
    import json

    from policy_analyzer import run_analysis

    sarif = to_sarif(run_analysis(REPO_ROOT), REPO_ROOT)
    json.dumps(sarif)  # must round-trip


# ---- expiry warnings ------------------------------------------------------ #


def test_expiring_within_window():
    exc = [Exception_("R", "o", "p", "j", "dpo", "2026-02-01")]
    soon = expiring_exceptions(exc, within_days=60, today=dt.date(2026, 1, 1))
    assert len(soon) == 1 and soon[0].days_left == 31


def test_already_expired_is_negative():
    exc = [Exception_("R", "o", "p", "j", "dpo", "2025-12-01")]
    soon = expiring_exceptions(exc, within_days=30, today=dt.date(2026, 1, 1))
    assert soon[0].days_left < 0


def test_far_future_not_flagged():
    exc = [Exception_("R", "o", "p", "j", "dpo", "2099-01-01")]
    assert expiring_exceptions(exc, within_days=30, today=dt.date(2026, 1, 1)) == []


def test_no_expiry_never_flagged():
    exc = [Exception_("R", "o", "p", "j", "dpo", "")]
    assert expiring_exceptions(exc, within_days=3650, today=dt.date(2026, 1, 1)) == []
