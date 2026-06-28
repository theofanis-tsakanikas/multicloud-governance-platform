"""Tests for the Level-B data pipelines: generator, medallion, profiler."""

from pathlib import Path

import generate_data
import medallion
from profile_data import _column_is_pii, build_profile

REPO_ROOT = Path(__file__).resolve().parent.parent


# --------------------------------------------------------------------------- #
# generator
# --------------------------------------------------------------------------- #


def test_generator_is_deterministic():
    written = generate_data.generate(REPO_ROOT, rows=40)
    assert written, "generator produced no datasets"
    sample = next(p for p in written if p.name.endswith("sales_rds_fed.crm.csv"))
    first = sample.read_text(encoding="utf-8")
    generate_data.generate(REPO_ROOT, rows=40)  # regenerate
    assert sample.read_text(encoding="utf-8") == first, "generator is not deterministic"


def test_pii_schema_gets_real_pii_columns():
    written = generate_data.generate(REPO_ROOT, rows=20)
    crm = next(p for p in written if p.name.endswith("sales_rds_fed.crm.csv"))
    header = crm.read_text(encoding="utf-8").splitlines()[0]
    assert "email" in header and "phone" in header


# --------------------------------------------------------------------------- #
# medallion
# --------------------------------------------------------------------------- #


def test_medallion_builds_all_layers(tmp_path):
    counts = medallion.run(REPO_ROOT, tmp_path / "wh.db")
    assert any(t.startswith("bronze__") for t in counts)
    assert any(t.startswith("silver__") for t in counts)
    assert "gold__global_kpis" in counts
    # cross-cloud KPI table spans the three clouds.
    assert counts["gold__global_kpis"] == 3


def test_gold_is_pii_minimised(tmp_path):
    import sqlite3

    db = tmp_path / "wh.db"
    medallion.run(REPO_ROOT, db)
    conn = sqlite3.connect(db)
    cols = [d[0] for d in conn.execute("SELECT * FROM gold__sales_customer_value LIMIT 1").description]
    conn.close()
    # gold keeps the pseudonymous id but drops direct PII carried in silver.
    assert "email" not in cols and "phone" not in cols and "full_name" not in cols
    assert "customer_id" in cols


# --------------------------------------------------------------------------- #
# profiler — observed vs declared
# --------------------------------------------------------------------------- #


def test_pii_detection():
    assert _column_is_pii("email", ["a@b.com", "c@d.org"])
    assert _column_is_pii("ip_address", ["10.0.0.1", "10.0.0.2"])
    assert _column_is_pii("full_name", ["Maria P", "Nikos G"])
    assert _column_is_pii("phone", ["+30 6912345678"])
    # negatives — dates / numbers / categories are not PII
    assert not _column_is_pii("sale_date", ["2024-08-15", "2024-09-01"])
    assert not _column_is_pii("revenue", ["123.45", "9.99"])
    assert not _column_is_pii("region", ["EU-West", "EU-South"])


def test_real_profile_is_consistent(tmp_path):
    profile = build_profile(REPO_ROOT, tmp_path / "wh.db")
    s = profile["summary"]
    assert s["classification_drift"] == 0, f"unexpected drift: {profile['classification_drift']}"
    assert s["gold_pii_minimised"] is True
    # exactly the two declared-pii schemas should carry observed PII
    pii_schemas = {x["schema"] for x in profile["schemas"] if x["observed_pii_columns"]}
    assert pii_schemas == {"sales_rds_fed.crm", "marketing_bq_fed.web"}


def test_drift_detected_when_pii_in_nonpii_schema(tmp_path):
    """If a schema declared non-pii actually holds PII, the profiler flags drift."""
    # Minimal repo: one MANAGED catalog, schema 'leak' declared 'internal',
    # with grants empty; then plant a PII column into its generated data.
    import json

    d = tmp_path / "environments" / "dev" / "domains" / "aws"
    d.mkdir(parents=True)
    (d / "x_infra.json").write_text(
        json.dumps(
            {
                "cloud": "AWS",
                "domain": "x",
                "catalogs": [
                    {
                        "catalog_name": "c",
                        "type": "MANAGED",
                        "owner": "data_engineers",
                        "schemas": [{"schema_name": "leak", "classification": "internal"}],
                    }
                ],
            }
        )
    )
    (d / "x_grants.json").write_text(json.dumps({}))
    # Hand-write a raw dataset with a real email column for c.leak.
    raw = tmp_path / "pipelines" / "data" / "raw" / "aws"
    raw.mkdir(parents=True)
    (raw / "c.leak.csv").write_text("id,email\n1,a@b.com\n2,c@d.com\n", encoding="utf-8")

    profile = build_profile(tmp_path, tmp_path / "wh.db")
    drift = profile["classification_drift"]
    assert any(x["schema"] == "c.leak" for x in drift), f"expected drift on c.leak, got {drift}"
