"""Tests for governance_metrics: deterministic telemetry over the model."""

import datetime as dt
from pathlib import Path

from governance_metrics import build_metrics, generate
from governance_model import GovernanceModel, Grant, Securable
from policy_analyzer import AnalysisResult, analyze

REPO_ROOT = Path(__file__).resolve().parent.parent


def _model():
    return GovernanceModel(
        securables=[
            Securable("AWS", "d", "catalog", "c", owner="data_engineers"),
            Securable("AWS", "d", "catalog", "c2", owner=None),
            Securable("AWS", "d", "schema", "c.pii", classification="pii"),
            Securable("AWS", "d", "schema", "c.un", classification=None),
        ],
        grants=[Grant("AWS", "d", "schema", "c.pii", "metastore_admins", ("ALL_PRIVILEGES",), classification="pii")],
    )


def test_coverage_percentages(tmp_path):
    m = _model()
    result = AnalysisResult(analyze(m))
    metrics = build_metrics(m, result, tmp_path / "nope.json", today=dt.date(2026, 1, 1))
    assert metrics["coverage"]["schemas"] == 2
    assert metrics["coverage"]["schemas_classified"] == 1
    assert metrics["coverage"]["schemas_classified_pct"] == 50.0
    assert metrics["coverage"]["catalogs_owned"] == 1
    assert metrics["coverage"]["catalogs_owned_pct"] == 50.0
    assert metrics["pii"]["datasets"] == 1


def test_exception_timeline(tmp_path):
    exc = tmp_path / "exc.json"
    exc.write_text(
        '{"exceptions": [{"rule": "PII_BROAD_READ", "object": "schema:c.pii", "principal": "x", "expires": "2026-02-15"}]}',
        encoding="utf-8",
    )
    m = _model()
    metrics = build_metrics(m, AnalysisResult(analyze(m)), exc, today=dt.date(2026, 1, 1))
    assert metrics["exceptions"]["total"] == 1
    assert metrics["exceptions"]["expiring_within_60d"] == 1
    assert metrics["exceptions"]["expiring_within_30d"] == 0


def test_real_repo_metrics_have_no_gating():
    metrics = generate(REPO_ROOT)
    assert metrics["posture"]["gating"] == 0
    assert metrics["coverage"]["schemas_classified_pct"] == 100.0
