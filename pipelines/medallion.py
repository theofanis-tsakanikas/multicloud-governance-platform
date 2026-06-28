#!/usr/bin/env python3
"""A real bronze → silver → gold medallion pipeline — in stdlib ``sqlite3``.

Level B of the data story (see pipelines/README.md). On the live platform these
transformations run as Spark SQL on Databricks across three clouds (the deferred
SQL is in ``pipelines/databricks/``). Here they run **offline, in sqlite** — a
real SQL engine in the standard library — so a reviewer sees data actually flow
through the governed catalogs with zero dependencies and zero cloud.

Why this is on-thesis, not an analytics detour:

* **gold is PII-minimised by construction.** The silver layer carries the PII
  columns from the federated CRM / web sources; the gold layer aggregates them
  away (counts by country, revenue by region) — so the pipeline *demonstrates*
  the data-protection posture the governance layer asserts.
* **the cross-cloud KPI table is the Delta Sharing story, executed.** GCP
  marketing gold is joined with AWS sales gold into one ``global_kpis`` table —
  the same "one governance/analytics plane across clouds" the platform claims,
  shown moving data instead of just declaring a share.

Layers (table prefix → meaning):

    bronze__<cloud>__<catalog>__<schema>   raw ingested copy
    silver__<...>                          cleaned + de-duplicated, typed on read
    gold__<name>                           curated, aggregated, PII-minimised

Output: ``pipelines/data/warehouse.db`` (+ gold CSVs under ``pipelines/data/gold/``),
both git-ignored and regenerated on demand.

Usage::

    python pipelines/medallion.py            # build the warehouse from raw data
"""

from __future__ import annotations

import argparse
import csv
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_data  # noqa: E402

RAW_DIR = Path("pipelines/data/raw")
WAREHOUSE_DB = Path("pipelines/data/warehouse.db")
GOLD_DIR = Path("pipelines/data/gold")


def _table(prefix: str, cloud: str, fqn: str) -> str:
    return f"{prefix}__{cloud.lower()}__{fqn.replace('.', '__')}"


def _ensure_raw(repo_root: Path, rows: int = 120) -> None:
    if not list((repo_root / RAW_DIR).glob("**/*.csv")):
        generate_data.generate(repo_root, rows)


# --------------------------------------------------------------------------- #
# Bronze — raw ingestion
# --------------------------------------------------------------------------- #


def load_bronze(conn: sqlite3.Connection, repo_root: Path) -> dict[str, str]:
    """Load every raw CSV into a bronze table. Returns {schema_fqn: table_name}."""
    mapping: dict[str, str] = {}
    for csv_path in sorted((repo_root / RAW_DIR).glob("**/*.csv")):
        cloud = csv_path.parent.name
        fqn = csv_path.stem  # "<catalog>.<schema>"
        with csv_path.open(encoding="utf-8") as fh:
            reader = csv.reader(fh)
            header = next(reader)
            rows = list(reader)
        table = _table("bronze", cloud, fqn)
        cols = ", ".join(f'"{c}" TEXT' for c in header)
        conn.execute(f'DROP TABLE IF EXISTS "{table}"')
        conn.execute(f'CREATE TABLE "{table}" ({cols})')
        placeholders = ", ".join("?" for _ in header)
        conn.executemany(f'INSERT INTO "{table}" VALUES ({placeholders})', rows)
        mapping[f"{cloud}:{fqn}"] = table
    conn.commit()
    return mapping


# --------------------------------------------------------------------------- #
# Silver — clean + de-duplicate (carries source columns, incl. PII from CRM/web)
# --------------------------------------------------------------------------- #


def build_silver(conn: sqlite3.Connection, bronze: dict[str, str]) -> dict[str, str]:
    silver: dict[str, str] = {}
    for key, btable in bronze.items():
        stable = btable.replace("bronze__", "silver__", 1)
        conn.execute(f'DROP TABLE IF EXISTS "{stable}"')
        conn.execute(f'CREATE TABLE "{stable}" AS SELECT DISTINCT * FROM "{btable}"')
        silver[key] = stable
    conn.commit()
    return silver


# --------------------------------------------------------------------------- #
# Gold — curated, aggregated, PII-minimised + the cross-cloud join
# --------------------------------------------------------------------------- #


def build_gold(conn: sqlite3.Connection, silver: dict[str, str]) -> list[str]:
    gold: list[str] = []

    def s(key: str) -> str | None:
        return silver.get(key)

    def make(name: str, sql: str) -> None:
        conn.execute(f'DROP TABLE IF EXISTS "{name}"')
        conn.execute(f'CREATE TABLE "{name}" AS {sql}')
        gold.append(name)

    # ---- AWS sales ---------------------------------------------------------
    if s("aws:sales_aws.silver"):
        make(
            "gold__sales_revenue_by_region",
            f"SELECT region, COUNT(*) AS sales, ROUND(SUM(CAST(revenue AS REAL)), 2) AS revenue "
            f'FROM "{s("aws:sales_aws.silver")}" GROUP BY region ORDER BY revenue DESC',
        )
    if s("aws:sales_rds_fed.crm") and s("aws:sales_rds_fed.orders"):
        # gold drops email/phone — PII stays in silver, gold keeps only pseudonymous id + country.
        make(
            "gold__sales_customer_value",
            f"SELECT c.customer_id, c.country, COUNT(o.order_id) AS orders, "
            f"ROUND(SUM(CAST(o.amount AS REAL)), 2) AS total_amount "
            f'FROM "{s("aws:sales_rds_fed.crm")}" c '
            f'LEFT JOIN "{s("aws:sales_rds_fed.orders")}" o ON o.customer_id = c.customer_id '
            f"GROUP BY c.customer_id, c.country",
        )

    # ---- Azure supply chain ------------------------------------------------
    if s("azure:supplies_azure.silver"):
        make(
            "gold__supply_supplier_leadtime",
            f"SELECT supplier_id, COUNT(*) AS shipments, "
            f"ROUND(AVG(CAST(lead_time_days AS REAL)), 1) AS avg_lead_days, "
            f"SUM(CAST(units AS INTEGER)) AS total_units "
            f'FROM "{s("azure:supplies_azure.silver")}" GROUP BY supplier_id ORDER BY avg_lead_days',
        )
    if s("azure:supply_sql_master.inventory"):
        make(
            "gold__supply_inventory_status",
            f"SELECT warehouse, COUNT(*) AS skus, "
            f"SUM(CASE WHEN CAST(on_hand AS INTEGER) < CAST(reorder_point AS INTEGER) THEN 1 ELSE 0 END) AS below_reorder "
            f'FROM "{s("azure:supply_sql_master.inventory")}" GROUP BY warehouse',
        )

    # ---- GCP marketing -----------------------------------------------------
    if s("gcp:marketing_bq_fed.analytics"):
        make(
            "gold__marketing_campaign_perf",
            f"SELECT campaign_id, SUM(CAST(impressions AS INTEGER)) AS impressions, "
            f"SUM(CAST(clicks AS INTEGER)) AS clicks, "
            f"ROUND(100.0 * SUM(CAST(clicks AS REAL)) / NULLIF(SUM(CAST(impressions AS REAL)), 0), 2) AS ctr_pct, "
            f"ROUND(SUM(CAST(spend AS REAL)), 2) AS spend "
            f'FROM "{s("gcp:marketing_bq_fed.analytics")}" GROUP BY campaign_id',
        )
    if s("gcp:marketing_bq_fed.web"):
        # gold__..._by_country aggregates web PII (email/ip) away to bare counts.
        make(
            "gold__marketing_web_by_country",
            f"SELECT country, COUNT(DISTINCT session_id) AS sessions "
            f'FROM "{s("gcp:marketing_bq_fed.web")}" GROUP BY country ORDER BY sessions DESC',
        )

    # ---- Cross-cloud KPI table (the Delta Sharing story, executed) ---------
    parts = []
    if "gold__sales_revenue_by_region" in gold:
        parts.append(
            "SELECT 'AWS' AS cloud, 'sales' AS domain, 'revenue' AS kpi, ROUND(SUM(revenue), 2) AS value FROM gold__sales_revenue_by_region"
        )
    if "gold__supply_supplier_leadtime" in gold:
        parts.append(
            "SELECT 'AZURE' AS cloud, 'supply_chain' AS domain, 'units_shipped' AS kpi, "
            "SUM(total_units) AS value FROM gold__supply_supplier_leadtime"
        )
    if "gold__marketing_campaign_perf" in gold:
        parts.append(
            "SELECT 'GCP' AS cloud, 'marketing' AS domain, 'campaign_spend' AS kpi, "
            "ROUND(SUM(spend), 2) AS value FROM gold__marketing_campaign_perf"
        )
    if parts:
        make("gold__global_kpis", " UNION ALL ".join(parts))

    conn.commit()
    return gold


def export_gold(conn: sqlite3.Connection, repo_root: Path, gold: list[str]) -> None:
    gold_dir = repo_root / GOLD_DIR
    gold_dir.mkdir(parents=True, exist_ok=True)
    for table in gold:
        cur = conn.execute(f'SELECT * FROM "{table}"')
        cols = [d[0] for d in cur.description]
        with (gold_dir / f"{table}.csv").open("w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(cols)
            w.writerows(cur.fetchall())


def run(repo_root: str | Path, db_path: Path | None = None) -> dict[str, int]:
    """Build the whole warehouse. Returns {table: row_count} for every layer."""
    repo_root = Path(repo_root).resolve()
    _ensure_raw(repo_root)
    db = db_path or (repo_root / WAREHOUSE_DB)
    db.parent.mkdir(parents=True, exist_ok=True)
    if db.exists():
        db.unlink()
    conn = sqlite3.connect(db)
    try:
        bronze = load_bronze(conn, repo_root)
        silver = build_silver(conn, bronze)
        gold = build_gold(conn, silver)
        export_gold(conn, repo_root, gold)

        counts: dict[str, int] = {}
        for table in list(bronze.values()) + list(silver.values()) + gold:
            counts[table] = conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
        return counts
    finally:
        conn.commit()
        conn.close()


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build the bronze→silver→gold medallion warehouse in sqlite (offline).")
    parser.add_argument("--root", default=str(_default_repo_root()))
    args = parser.parse_args(argv)

    counts = run(args.root)
    bronze = sum(1 for t in counts if t.startswith("bronze__"))
    silver = sum(1 for t in counts if t.startswith("silver__"))
    gold = sorted(t for t in counts if t.startswith("gold__"))
    print(f"warehouse built: {bronze} bronze, {silver} silver, {len(gold)} gold tables → {WAREHOUSE_DB}")
    for t in gold:
        print(f"  {t}: {counts[t]} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
