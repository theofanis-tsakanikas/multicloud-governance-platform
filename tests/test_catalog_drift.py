"""Tests for catalog_drift: the pure reconciliation logic (no cloud needed)."""

from pathlib import Path

from catalog_drift import diff_grants, expected_grants
from governance_model import GovernanceModel, Grant, build_model

REPO_ROOT = Path(__file__).resolve().parent.parent


def _g(principal, privs, fqn="c.s"):
    return Grant("AWS", "d", "schema", fqn, principal, tuple(privs), classification="internal")


def test_in_sync_when_identical():
    m = GovernanceModel(grants=[_g("analysts", ["SELECT"])])
    exp = expected_grants(m)
    report = diff_grants(exp, set(exp))
    assert report.in_sync


def test_missing_in_catalog():
    m = GovernanceModel(grants=[_g("analysts", ["SELECT"])])
    exp = expected_grants(m)
    report = diff_grants(exp, set())  # live catalog has nothing
    assert not report.in_sync
    assert len(report.missing_in_catalog) == 1
    assert report.as_dict()["missing_in_catalog"][0]["principal"] == "analysts"


def test_extra_in_catalog():
    m = GovernanceModel(grants=[_g("analysts", ["SELECT"])])
    exp = expected_grants(m)
    live = set(exp) | expected_grants(GovernanceModel(grants=[_g("ghost", ["SELECT"])]))
    report = diff_grants(exp, live)
    assert not report.in_sync
    assert report.as_dict()["extra_in_catalog"][0]["principal"] == "ghost"


def test_privilege_change_is_drift():
    declared = expected_grants(GovernanceModel(grants=[_g("analysts", ["SELECT"])]))
    live = expected_grants(GovernanceModel(grants=[_g("analysts", ["SELECT", "MODIFY"])]))
    report = diff_grants(declared, live)
    # Same principal+object but different privilege set → both a missing and an extra.
    assert len(report.missing_in_catalog) == 1
    assert len(report.extra_in_catalog) == 1


def test_real_repo_expected_grants_nonempty():
    m = build_model(REPO_ROOT)
    assert len(expected_grants(m)) > 0
