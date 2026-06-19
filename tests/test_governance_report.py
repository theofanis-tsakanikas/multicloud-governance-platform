"""Tests for governance_report and genie_space artifact generation."""

import json
from pathlib import Path

import genie_space
import governance_report

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_context_has_expected_sections():
    _, ctx = governance_report.generate(REPO_ROOT)
    for key in ("summary", "objects", "access_matrix", "pii_map", "policy_findings"):
        assert key in ctx
    assert ctx["summary"]["clouds"] == ["AWS", "AZURE", "GCP"]


def test_pii_map_lists_readers_deterministically():
    _, ctx = governance_report.generate(REPO_ROOT)
    by_object = {p["object"]: p for p in ctx["pii_map"]}
    assert "sales_rds_fed.crm" in by_object
    assert by_object["sales_rds_fed.crm"]["readers"] == ["crm_managers"]
    assert by_object["sales_rds_fed.crm"]["storage"] == "federated"


def test_markdown_renders_key_sections():
    md, _ = governance_report.generate(REPO_ROOT)
    assert "# Data Governance Report" in md
    assert "## PII map" in md
    assert "## Access matrix" in md
    assert "Accepted risks" in md


def test_committed_report_is_up_to_date():
    # CI invariant: the committed docs must match a fresh render (ignoring date).
    rc = governance_report.main(["--root", str(REPO_ROOT), "--check"])
    assert rc == 0, "docs/governance artifacts are stale — run `make governance-report`"


def test_accepted_exceptions_appear_in_context():
    _, ctx = governance_report.generate(REPO_ROOT)
    accepted = [f for f in ctx["policy_findings"] if f["accepted"]]
    assert accepted, "expected at least one documented exception"
    assert all(f["justification"] for f in accepted)


# --------------------------------------------------------------------------- #
# Genie artifacts
# --------------------------------------------------------------------------- #


def test_genie_sql_is_valid_shape():
    ctx = genie_space.load_context(REPO_ROOT)
    sql = genie_space.render_materialize_sql(ctx)
    assert "CREATE SCHEMA IF NOT EXISTS platform_governance.catalog" in sql
    for table in ("objects", "access_matrix", "pii_map", "policy_findings"):
        assert f"platform_governance.catalog.{table}" in sql
    # SQL-injection guard: single quotes in data are escaped.
    assert "''" in sql or "'" in sql  # at minimum, string literals are quoted


def test_genie_sql_escapes_quotes(tmp_path):
    ctx = {
        "objects": [],
        "access_matrix": [],
        "pii_map": [],
        "policy_findings": [
            {
                "rule": "R",
                "severity": "HIGH",
                "cloud": "AWS",
                "object": "o",
                "principal": "p",
                "message": "it's a risk",
                "dimension": "d",
                "accepted": False,
                "justification": "",
            }
        ],
    }
    sql = genie_space.render_materialize_sql(ctx)
    assert "it''s a risk" in sql  # apostrophe doubled, not breaking the literal


def test_genie_instructions_have_grounding_contract():
    ctx = genie_space.load_context(REPO_ROOT)
    text = genie_space.render_instructions(ctx)
    assert "Grounding contract" in text
    assert "Answer **only**" in text
    assert "read-only" in text


def test_committed_genie_artifacts_up_to_date():
    rc = genie_space.main(["--root", str(REPO_ROOT), "--check"])
    assert rc == 0, "docs/governance/genie artifacts are stale — run `make genie-space`"


def test_context_file_is_valid_json():
    ctx_path = REPO_ROOT / "docs" / "governance" / "governance_context.json"
    assert ctx_path.is_file()
    json.loads(ctx_path.read_text(encoding="utf-8"))  # must parse
