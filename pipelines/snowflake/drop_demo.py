#!/usr/bin/env python3
"""Drop the Snowflake demo scaffolding so Terraform can drop the stages it stands on.

The mirror of read_gold_zone.sql / masking_demo.sql / deploy_notebook.py, and the twin of
pipelines/sources/azure_sql/drop_seed.py — the same lesson in a different engine: Terraform can
only drop what it created, so whatever created the rest has to take it back down, and first.

    093694 (42601): Stage loc_sales_gold cannot be dropped or replaced or have its URL
    altered because it has active External table(s) using it.

Terraform owns the stage. It does not own `"sales_aws"."demo"."executive_cross_cloud"` — the
external table the zero-copy demo lays over the Parquet the medallion exports — nor the masking
demo's PII table and policy, nor the notebook. All of it sits in the ungoverned `demo` schema.

⚠ AND THE OBVIOUS FIX DOES NOT WORK. `DROP SCHEMA ... CASCADE` does not delete anything: it
moves the schema into **Time Travel**, recoverable by UNDROP for the retention period (1 day by
default). The external table goes with it — still real, still pointing at the stage. Snowflake
therefore keeps refusing to drop the stage, because an UNDROP would restore a table whose stage
no longer exists. The teardown cannot succeed until Time Travel expires, which is not a plan.

So this script does three things, and the order is the whole point:

  1. Collapse the database's retention to zero. This evicts anything already sitting in Time
     Travel from previous CASCADE drops — otherwise those ghosts keep the stage pinned no matter
     how carefully we drop things from here on.
  2. Drop the external tables EXPLICITLY, by name. An external table has no Time Travel of its
     own, so an explicit DROP is a real delete — unlike the same table swept up in a CASCADE.
  3. Only then drop the schema.

Idempotent, and a no-op if the demo was never deployed, so re-running a failed destroy is safe.

    SNOWFLAKE_ACCOUNT / SNOWFLAKE_USER / SNOWFLAKE_PASSWORD / SNOWFLAKE_ROLE
"""

import os
import sys

import snowflake.connector

DATABASE = '"sales_aws"'
DEMO_SCHEMA = '"sales_aws"."demo"'


def main() -> int:
    try:
        con = snowflake.connector.connect(
            account=os.environ["SNOWFLAKE_ACCOUNT"],
            user=os.environ["SNOWFLAKE_USER"],
            password=os.environ["SNOWFLAKE_PASSWORD"],
            role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
            login_timeout=30,
        )
    except KeyError as missing:
        sys.exit(f"drop_demo: missing required env var {missing}")

    cur = con.cursor()

    # The database may already be gone (a re-run after a partial destroy). Nothing to clean up.
    try:
        cur.execute(f"USE DATABASE {DATABASE}")
    except Exception as exc:
        print(f"[demo] {DATABASE} is not there ({str(exc)[:60]}) — nothing to drop")
        con.close()
        return 0

    # ── 1. Evict Time Travel, including the ghosts of earlier CASCADE drops ──────────────
    # Reducing the retention period pushes anything beyond the new window out of Time Travel.
    # At zero that is everything — and it is those un-UNDROP-able ghosts, not any live object,
    # that have been pinning the stage. The database is being destroyed in the next breath;
    # there is nothing here worth being able to recover.
    cur.execute(f"ALTER DATABASE {DATABASE} SET DATA_RETENTION_TIME_IN_DAYS = 0")
    print(f"[demo] {DATABASE} retention -> 0 (evicts dropped schemas from Time Travel)")

    # ── 2. Drop external tables by name — a CASCADE would only Time-Travel them ──────────
    cur.execute(f"SHOW EXTERNAL TABLES IN DATABASE {DATABASE}")
    cols = [d[0] for d in cur.description]
    externals = [dict(zip(cols, r)) for r in cur.fetchall()]
    for t in externals:
        fqn = f'"{t["database_name"]}"."{t["schema_name"]}"."{t["name"]}"'
        cur.execute(f"DROP EXTERNAL TABLE IF EXISTS {fqn}")
        print(f"[demo] dropped external table {fqn}")
    if not externals:
        print("[demo] no live external tables")

    # ── 3. Now the schema, with nothing left in it that can outlive the drop ─────────────
    cur.execute(f"DROP SCHEMA IF EXISTS {DEMO_SCHEMA} CASCADE")
    print(f"[demo] dropped {DEMO_SCHEMA}")

    # ── Prove it. The provider's error names the stage, never the thing blocking it, so a
    # silent miss here costs another full destroy run to diagnose. Assert instead.
    cur.execute(f"SHOW SCHEMAS HISTORY IN DATABASE {DATABASE}")
    cols = [d[0] for d in cur.description]
    ghosts = [dict(zip(cols, r)) for r in cur.fetchall()]
    ghosts = [g["name"] for g in ghosts if g.get("dropped_on")]
    if ghosts:
        print("[demo] schemas still recoverable from Time Travel — the stage stays pinned:")
        for g in ghosts:
            print(f"[demo]   {g}")
        con.close()
        sys.exit("drop_demo: Time Travel still holds a schema; terraform's DROP STAGE would fail")

    print("[demo] nothing left in Time Travel; terraform can drop the stages")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
