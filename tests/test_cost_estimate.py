"""Tests for cost_estimate: the deterministic cost + carbon floor."""

from pathlib import Path

from cost_estimate import compute, generate

REPO_ROOT = Path(__file__).resolve().parent.parent

ASSUMPTIONS = {
    "currency": "USD",
    "databricks": {
        "warehouse_size": "Small",
        "dbu_per_hour": {"Small": 12},
        "usd_per_dbu": 0.70,
        "hours_per_day": 10,
        "days_per_month": 22,
        "power_kw": {"Small": 1.0},
    },
    "infra_monthly_usd": {
        "AWS": {"rds": 100, "_comment": "ignored"},
        "Azure": {"sql": 200},
    },
    "carbon": {"grid_intensity_g_per_kwh": {"AWS": 300}, "pue": 1.0},
}


def test_compute_arithmetic():
    est = compute(ASSUMPTIONS)
    # 12 DBU/hr * 10h * 22d = 2640 DBUs; * 0.70 = 1848.0
    assert est["databricks"]["dbus_per_month"] == 2640
    assert est["databricks"]["monthly_usd"] == 1848.0
    # infra: AWS 100 (comment skipped) + Azure 200 = 300
    assert est["infra_per_cloud_usd"]["AWS"] == 100.0
    assert est["infra_total_usd"] == 300.0
    assert est["total_monthly_usd"] == 2148.0


def test_carbon_estimate():
    est = compute(ASSUMPTIONS)
    # 1.0 kW * 220h * pue 1.0 = 220 kWh; * 300 g / 1000 = 66.0 kg
    assert est["carbon"]["warehouse_kwh_per_month"] == 220.0
    assert est["carbon"]["warehouse_kg_co2e_per_month"] == 66.0


def test_real_repo_renders():
    markdown, est = generate(REPO_ROOT)
    assert "monthly floor" in markdown
    assert est["total_monthly_usd"] > 0
