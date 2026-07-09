"""Tests for the static governance dashboard (Level A)."""

from pathlib import Path

from governance_dashboard import generate, render_html

REPO_ROOT = Path(__file__).resolve().parent.parent

_METRICS = {
    "posture": {"open_high": 0, "open_medium": 6, "open_low": 0, "info": 2, "accepted_risks": 2, "gating": 0},
    "coverage": {
        "schemas": 12,
        "schemas_classified": 12,
        "schemas_classified_pct": 100.0,
        "catalogs": 6,
        "catalogs_owned": 6,
        "catalogs_owned_pct": 100.0,
    },
    "footprint": {"clouds": ["AWS", "AZURE", "GCP"], "domains": ["sales", "supply_chain", "marketing"], "objects": 29, "grants": 66},
    "exceptions": {"total": 2, "expired": 0, "expiring_within_30d": 0, "expiring_within_60d": 0, "expiring_within_90d": 1},
}
_COST = {
    "currency": "USD",
    "databricks": {"monthly_usd": 1848.0},
    "infra_total_usd": 498.0,
    "total_monthly_usd": 2346.0,
    "carbon": {"warehouse_kg_co2e_per_month": 78.8},
}


def test_render_contains_key_sections():
    out = render_html(_METRICS, None, None, _COST)
    assert "Multi-Cloud Governance Dashboard" in out
    assert "GATE: PASSING" in out
    assert "Policy posture" in out
    assert "Cost &amp; carbon floor" in out


def test_gate_blocked_when_gating():
    blocked = dict(_METRICS, posture=dict(_METRICS["posture"], gating=3))
    out = render_html(blocked, None, None, _COST)
    assert "GATE: BLOCKED" in out


def test_profile_section_renders_when_present():
    profile = {
        "summary": {
            "governed_schemas": 12,
            "rows_profiled": 1440,
            "schemas_with_pii": 2,
            "classification_drift": 0,
            "gold_tables": 7,
            "gold_pii_minimised": True,
        }
    }
    out = render_html(_METRICS, None, profile, _COST)
    assert "Data reconciliation" in out
    assert "PII-minimised" in out
    assert "no drift" in out


def test_self_contained_no_external_urls():
    out = render_html(_METRICS, None, None, _COST)
    assert "http://" not in out and "https://" not in out
    assert "<script" not in out  # no JS


def test_generate_on_real_repo_is_deterministic():
    first = generate(REPO_ROOT)
    second = generate(REPO_ROOT)
    assert first == second
    assert first.strip().endswith("</html>")
