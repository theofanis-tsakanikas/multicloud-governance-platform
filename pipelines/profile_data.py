#!/usr/bin/env python3
"""Profile the warehouse and reconcile OBSERVED data against DECLARED governance.

Level B's payoff and the bridge back to the thesis. The platform *declares* a
classification per schema in the domain JSON. This profiles the data that
actually landed and asks two questions a declaration alone can't answer:

1. **Does the data match its declaration?** For every governed (silver) schema,
   detect PII-shaped columns (by name and by value) and compare against the
   declared classification. A ``pii`` column in a schema *not* classified ``pii``
   is **classification drift** — exactly the gap between "what we said" and "what
   is true" that a declaration-only model can't catch.
2. **Is gold actually PII-minimised?** The curated gold layer should carry no
   PII. The profiler asserts it — turning the platform's data-protection claim
   into a checked fact.

Deterministic: the data is generated from fixed seeds, so the profile is
reproducible and CI can ``--check`` it like the other governance artifacts.

Output: ``docs/governance/data_profile.json`` (committed — it is small and
deterministic; the bulk warehouse it derives from is git-ignored).

Usage::

    python pipelines/profile_data.py            # write docs/governance/data_profile.json
    python pipelines/profile_data.py --check     # fail if the committed profile is stale
    python pipelines/profile_data.py --stdout    # print JSON, write nothing
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import medallion  # noqa: E402

from governance_model import build_model  # noqa: E402

DATA_PROFILE = Path("docs/governance/data_profile.json")
RAW_DIR = Path("pipelines/data/raw")

# Column-name hints and value patterns that indicate personal data.
_PII_NAME = re.compile(
    r"(email|e_mail|phone|mobile|ssn|passport|ip_address|full_name|first_name|last_name|\bname\b|\baddress\b|dob|birth)", re.I
)
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
# Leading '+' required so ISO dates (e.g. 2024-08-15) are not mistaken for phones.
_PHONE_RE = re.compile(r"^\+\d[\d\s]{6,}$")
_IP_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")
_VALUE_RES = (_EMAIL_RE, _PHONE_RE, _IP_RE)


def _column_is_pii(name: str, sample: list[str]) -> bool:
    if _PII_NAME.search(name):
        return True
    if not sample:
        return False
    hits = sum(1 for v in sample if any(rx.match(v or "") for rx in _VALUE_RES))
    return hits >= max(1, len(sample) // 2)


def _profile_table(conn: sqlite3.Connection, table: str) -> tuple[int, list[str], list[str]]:
    """Return (row_count, columns, pii_columns) for a table."""
    cur = conn.execute(f'SELECT * FROM "{table}" LIMIT 50')
    columns = [d[0] for d in cur.description]
    sample_rows = cur.fetchall()
    rows = conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
    pii_cols = []
    for i, col in enumerate(columns):
        sample = [str(r[i]) for r in sample_rows]
        if _column_is_pii(col, sample):
            pii_cols.append(col)
    return rows, columns, pii_cols


def build_profile(repo_root: Path, db_path: Path | None = None, *, today: _dt.date | None = None) -> dict:
    repo_root = Path(repo_root).resolve()
    today = today or _dt.date.today()
    db = db_path or (repo_root / medallion.WAREHOUSE_DB)
    medallion.run(repo_root, db)  # idempotent rebuild → deterministic

    model = build_model(repo_root)
    # Key by lower-cased cloud to match the raw directory names (aws/azure/gcp).
    declared = {f"{s.cloud.lower()}:{s.fqn}": s.classification for s in model.securables if s.object_type == "schema"}

    conn = sqlite3.connect(db)
    try:
        schemas = []
        drift = []
        # Governed (silver) schemas: reconcile observed vs declared.
        for csv_path in sorted((repo_root / RAW_DIR).glob("**/*.csv")):
            cloud = csv_path.parent.name
            fqn = csv_path.stem
            key = f"{cloud}:{fqn}"
            silver = medallion._table("silver", cloud, fqn)
            try:
                rows, columns, pii_cols = _profile_table(conn, silver)
            except sqlite3.OperationalError:
                continue
            decl = declared.get(key)
            observed_pii = bool(pii_cols)
            # Drift: real PII present where the declaration doesn't say pii.
            is_drift = observed_pii and decl != "pii"
            schemas.append(
                {
                    "cloud": cloud.upper(),
                    "schema": fqn,
                    "rows": rows,
                    "columns": len(columns),
                    "declared_classification": decl,
                    "observed_pii_columns": pii_cols,
                    "consistent": not is_drift,
                }
            )
            if is_drift:
                drift.append({"cloud": cloud.upper(), "schema": fqn, "declared": decl, "pii_columns": pii_cols})

        # Gold layer: must be PII-minimised.
        gold = []
        gold_pii_leaks = []
        for (table,) in conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'gold__%' ORDER BY name"):
            rows, columns, pii_cols = _profile_table(conn, table)
            gold.append({"table": table, "rows": rows, "columns": len(columns), "pii_columns": pii_cols})
            if pii_cols:
                gold_pii_leaks.append({"table": table, "pii_columns": pii_cols})

        return {
            "generated_at": today.isoformat(),
            "summary": {
                "governed_schemas": len(schemas),
                "rows_profiled": sum(s["rows"] for s in schemas),
                "schemas_with_pii": sum(1 for s in schemas if s["observed_pii_columns"]),
                "classification_drift": len(drift),
                "gold_tables": len(gold),
                "gold_pii_minimised": not gold_pii_leaks,
            },
            "schemas": schemas,
            "classification_drift": drift,
            "gold_layer": gold,
            "gold_pii_leaks": gold_pii_leaks,
        }
    finally:
        conn.close()


def _strip_date(text: str) -> str:
    return "\n".join(line for line in text.splitlines() if '"generated_at"' not in line)


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Profile the warehouse and reconcile observed data vs declared governance.")
    parser.add_argument("--root", default=str(_default_repo_root()))
    parser.add_argument("--check", action="store_true", help="fail if the committed data_profile.json is stale")
    parser.add_argument("--stdout", action="store_true", help="print JSON, write nothing")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    profile = build_profile(root)
    payload = json.dumps(profile, indent=2) + "\n"

    if args.stdout:
        print(payload, end="")
        return 0

    path = root / DATA_PROFILE
    if args.check:
        existing = path.read_text(encoding="utf-8") if path.is_file() else ""
        if _strip_date(existing) != _strip_date(payload):
            print(f"STALE data profile (run `make data`): {DATA_PROFILE}")
            return 1
        print("data profile is up to date.")
        return 0

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(payload, encoding="utf-8")
    s = profile["summary"]
    print(
        f"wrote {DATA_PROFILE} — {s['governed_schemas']} schemas, {s['rows_profiled']} rows, "
        f"{s['classification_drift']} drift, gold PII-minimised: {s['gold_pii_minimised']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
