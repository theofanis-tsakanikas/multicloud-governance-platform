#!/usr/bin/env python3
"""Deterministic synthetic data generator — data shaped by the governance model.

Level B of the data story (see pipelines/README.md). This does NOT invent a data
model: it reads the *same* governance model the analyzer reasons over
(``scripts/governance_model.py``) and generates one raw dataset per governed
schema. Where a schema is classified ``pii`` it emits columns that actually
contain PII-shaped values (emails, phones, IPs) — so the platform's PII controls
can later be demonstrated against real columns, not just a JSON declaration.

It is **deterministic**: every value derives from a fixed seed keyed on the
schema name, so regenerating produces byte-identical CSVs and the downstream
profile is reproducible (CI ``--check``). No randomness leaks, no wall-clock.

Output: ``pipelines/data/raw/<cloud>/<catalog>.<schema>.csv`` (git-ignored — bulk
data is regenerated on demand; only the derived profile is committed).

Usage::

    python pipelines/generate_data.py            # write all raw datasets
    python pipelines/generate_data.py --rows 120  # rows per dataset
"""

from __future__ import annotations

import argparse
import csv
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from governance_model import Securable, build_model  # noqa: E402

RAW_DIR = Path("pipelines/data/raw")

# A fixed epoch so generated dates are stable (no wall-clock).
_EPOCH_DAYS = 20000  # days since 1970 → 2024-10-04, an arbitrary fixed anchor

_FIRST = ["Maria", "Giorgos", "Eleni", "Nikos", "Sofia", "Dimitris", "Katerina", "Yannis", "Anna", "Kostas"]
_LAST = ["Papadopoulos", "Nikolaou", "Georgiou", "Vasileiou", "Ioannou", "Makris", "Antoniou", "Pappas"]
_COUNTRIES = ["GR", "DE", "FR", "NL", "IT", "ES"]
_REGIONS = ["EU-South", "EU-West", "EU-North", "EU-Central"]
_CHANNELS = ["search", "social", "email", "display"]
_STATUSES = ["NEW", "SHIPPED", "CLOSED", "CANCELLED"]


def _date(rng: random.Random) -> str:
    d = _EPOCH_DAYS + rng.randint(-300, 0)
    # Convert day-number to ISO date without touching the system clock.
    import datetime as _dt

    return (_dt.date(1970, 1, 1) + _dt.timedelta(days=d)).isoformat()


def _email(rng: random.Random, first: str, last: str) -> str:
    return f"{first.lower()}.{last.lower()}{rng.randint(1, 99)}@example.com"


def _phone(rng: random.Random) -> str:
    return f"+30 69{rng.randint(10000000, 99999999)}"


def _ip(rng: random.Random) -> str:
    return f"10.{rng.randint(0, 255)}.{rng.randint(0, 255)}.{rng.randint(1, 254)}"


# --------------------------------------------------------------------------- #
# Column specs: curated per known schema, generic fallback otherwise.
# A column is a (name, value_fn) pair; value_fn(rng, i) -> str.
# --------------------------------------------------------------------------- #


def _columns_for(schema_fqn: str, classification: str | None):
    rng_pick = lambda r, seq: seq[r.randrange(len(seq))]  # noqa: E731

    specs = {
        "sales_aws.bronze": [
            ("event_id", lambda r, i: f"evt_{i:05d}"),
            ("occurred_at", lambda r, i: _date(r)),
            ("store_id", lambda r, i: f"store_{r.randint(1, 12)}"),
            ("product_sku", lambda r, i: f"SKU-{r.randint(1000, 1099)}"),
            ("qty", lambda r, i: str(r.randint(1, 9))),
            ("unit_price", lambda r, i: f"{r.uniform(5, 200):.2f}"),
        ],
        "sales_aws.silver": [
            ("sale_id", lambda r, i: f"sale_{i:05d}"),
            ("sale_date", lambda r, i: _date(r)),
            ("region", lambda r, i: rng_pick(r, _REGIONS)),
            ("product_sku", lambda r, i: f"SKU-{r.randint(1000, 1099)}"),
            ("quantity", lambda r, i: str(r.randint(1, 9))),
            ("revenue", lambda r, i: f"{r.uniform(20, 1800):.2f}"),
        ],
        "sales_rds_fed.crm": [
            ("customer_id", lambda r, i: f"cust_{i:05d}"),
            ("full_name", lambda r, i: f"{rng_pick(r, _FIRST)} {rng_pick(r, _LAST)}"),
            ("email", lambda r, i: _email(r, rng_pick(r, _FIRST), rng_pick(r, _LAST))),
            ("phone", lambda r, i: _phone(r)),
            ("country", lambda r, i: rng_pick(r, _COUNTRIES)),
            ("segment", lambda r, i: rng_pick(r, ["SMB", "ENT", "CONSUMER"])),
        ],
        "sales_rds_fed.orders": [
            ("order_id", lambda r, i: f"ord_{i:05d}"),
            ("customer_id", lambda r, i: f"cust_{r.randint(0, 80):05d}"),
            ("order_date", lambda r, i: _date(r)),
            ("amount", lambda r, i: f"{r.uniform(15, 2500):.2f}"),
            ("status", lambda r, i: rng_pick(r, _STATUSES)),
        ],
        "supplies_azure.bronze": [
            ("shipment_id", lambda r, i: f"shp_{i:05d}"),
            ("shipped_at", lambda r, i: _date(r)),
            ("supplier_id", lambda r, i: f"sup_{r.randint(1, 25)}"),
            ("sku", lambda r, i: f"SKU-{r.randint(1000, 1099)}"),
            ("units", lambda r, i: str(r.randint(10, 500))),
        ],
        "supplies_azure.silver": [
            ("shipment_id", lambda r, i: f"shp_{i:05d}"),
            ("ship_date", lambda r, i: _date(r)),
            ("supplier_id", lambda r, i: f"sup_{r.randint(1, 25)}"),
            ("sku", lambda r, i: f"SKU-{r.randint(1000, 1099)}"),
            ("units", lambda r, i: str(r.randint(10, 500))),
            ("lead_time_days", lambda r, i: str(r.randint(1, 30))),
        ],
        "supply_sql_master.inventory": [
            ("sku", lambda r, i: f"SKU-{1000 + i}"),
            ("warehouse", lambda r, i: f"wh_{r.randint(1, 6)}"),
            ("on_hand", lambda r, i: str(r.randint(0, 2000))),
            ("reorder_point", lambda r, i: str(r.randint(50, 300))),
        ],
        "supply_sql_master.orders": [
            ("po_id", lambda r, i: f"po_{i:05d}"),
            ("supplier_id", lambda r, i: f"sup_{r.randint(1, 25)}"),
            ("order_date", lambda r, i: _date(r)),
            ("total_cost", lambda r, i: f"{r.uniform(500, 50000):.2f}"),
            ("status", lambda r, i: rng_pick(r, _STATUSES)),
        ],
        "marketing_gcp.intelligence": [
            ("model_id", lambda r, i: f"mdl_{i:04d}"),
            ("campaign_id", lambda r, i: f"camp_{r.randint(1, 40)}"),
            ("score", lambda r, i: f"{r.uniform(0, 1):.4f}"),
            ("segment", lambda r, i: rng_pick(r, ["A", "B", "C"])),
        ],
        "marketing_bq_fed.analytics": [
            ("campaign_id", lambda r, i: f"camp_{r.randint(1, 40)}"),
            ("channel", lambda r, i: rng_pick(r, _CHANNELS)),
            ("impressions", lambda r, i: str(r.randint(100, 100000))),
            ("clicks", lambda r, i: str(r.randint(1, 5000))),
            ("spend", lambda r, i: f"{r.uniform(10, 9000):.2f}"),
        ],
        "marketing_bq_fed.web": [
            ("session_id", lambda r, i: f"sess_{i:06d}"),
            ("user_email", lambda r, i: _email(r, rng_pick(r, _FIRST), rng_pick(r, _LAST))),
            ("ip_address", lambda r, i: _ip(r)),
            ("page", lambda r, i: rng_pick(r, ["/home", "/pricing", "/product", "/blog"])),
            ("event_ts", lambda r, i: _date(r)),
            ("country", lambda r, i: rng_pick(r, _COUNTRIES)),
        ],
    }
    if schema_fqn in specs:
        return specs[schema_fqn]

    # Generic fallback — auto-adapts to any new schema; injects PII if pii-classed.
    cols = [
        ("id", lambda r, i: f"row_{i:05d}"),
        ("label", lambda r, i: f"item-{r.randint(1, 999)}"),
        ("value", lambda r, i: f"{r.uniform(0, 1000):.2f}"),
        ("created_at", lambda r, i: _date(r)),
    ]
    if classification == "pii":
        cols.insert(1, ("email", lambda r, i: _email(r, rng_pick(r, _FIRST), rng_pick(r, _LAST))))
        cols.insert(2, ("phone", lambda r, i: _phone(r)))
    return cols


def _data_schemas(repo_root: Path) -> list[Securable]:
    """Schemas that should hold data — every schema securable in the model."""
    model = build_model(repo_root)
    return [s for s in model.securables if s.object_type == "schema"]


def generate(repo_root: Path, rows: int) -> list[Path]:
    written: list[Path] = []
    for s in _data_schemas(repo_root):
        cols = _columns_for(s.fqn, s.classification)
        rng = random.Random(f"{s.cloud}:{s.fqn}")  # deterministic per schema
        out = repo_root / RAW_DIR / s.cloud.lower() / f"{s.fqn}.csv"
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow([name for name, _ in cols])
            for i in range(rows):
                w.writerow([fn(rng, i) for _, fn in cols])
        written.append(out)
    return written


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate deterministic synthetic data shaped by the governance model.")
    parser.add_argument("--root", default=str(_default_repo_root()))
    parser.add_argument("--rows", type=int, default=120, help="rows per dataset (default: 120)")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    written = generate(root, args.rows)
    print(f"generated {len(written)} datasets ({args.rows} rows each) under {RAW_DIR}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
