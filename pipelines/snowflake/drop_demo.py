#!/usr/bin/env python3
"""Drop the Snowflake demo scaffolding so Terraform can drop the stages it stands on.

The mirror of read_gold_zone.sql / masking_demo.sql / deploy_notebook.py, and the twin of
pipelines/sources/azure_sql/drop_seed.py — the same lesson in a different engine: Terraform can
only drop what it created, so whatever created the rest has to take it back down, and first.

    093694 (42601): Stage loc_sales_gold cannot be dropped or replaced or have its URL
    altered because it has active External table(s) using it.

Terraform owns the stage. It does not own `"sales_aws"."demo"."executive_cross_cloud"` — the
external table the zero-copy demo lays over the Parquet the medallion exports. That table lives
in the ungoverned `demo` schema, and it is what pins the stage.

⚠ THE TWO OBVIOUS FIXES BOTH FAIL, and understanding why is the whole script.

  · `DROP SCHEMA ... CASCADE` does not delete the external table. It moves the schema — contents
    and all — into **Time Travel**, where UNDROP can bring it back for the retention period. The
    table is still real and still points at the stage, so Snowflake goes on refusing to drop the
    stage: an UNDROP would restore a table whose stage no longer exists. Worse, the blocker is
    invisible — SHOW EXTERNAL TABLES walks only live schemas and reports none.

  · Lowering the retention period does not evict what is already in there. Snowflake keeps the
    retention that was in force at drop time, so the ghosts sit out their full day regardless.

Every failed teardown attempt leaves another ghost, and every ghost pins the stage on its own.

The only way through is to peel them off one at a time. UNDROP restores the most recent ghost;
drop its external table EXPLICITLY (an external table has no Time Travel of its own, so an
explicit DROP is a real delete where a CASCADE is not); set the schema's retention to zero so
the next drop creates no new ghost; drop it. Repeat until no ghost of the demo schema remains.

Ghosts of other schemas are left alone: only an external table pins a stage, and only the demo
schema ever had one.

Idempotent, and a no-op if the demo was never deployed, so re-running a failed destroy is safe.

    SNOWFLAKE_ACCOUNT / SNOWFLAKE_USER / SNOWFLAKE_PASSWORD / SNOWFLAKE_ROLE
"""

import os
import sys

import snowflake.connector

DATABASE = '"sales_aws"'
DEMO = "demo"
DEMO_SCHEMA = f'"sales_aws"."{DEMO}"'
MAX_PEELS = 12  # a ghost per failed attempt; a dozen is far past any real history


def rows(cur, sql):
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def demo_ghosts(cur) -> int:
    """How many dropped `demo` schemas are still recoverable — i.e. still pinning the stage."""
    history = rows(cur, f"SHOW SCHEMAS HISTORY IN DATABASE {DATABASE}")
    return sum(1 for s in history if s.get("dropped_on") and s["name"].lower() == DEMO)


def drop_externals(cur) -> None:
    """Explicitly, by name. A CASCADE would only Time-Travel them."""
    for t in rows(cur, f"SHOW EXTERNAL TABLES IN DATABASE {DATABASE}"):
        fqn = f'"{t["database_name"]}"."{t["schema_name"]}"."{t["name"]}"'
        cur.execute(f"DROP EXTERNAL TABLE IF EXISTS {fqn}")
        print(f"[demo]   dropped external table {fqn}")


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

    # Take the live schema down first, properly — external tables by name, then the schema with
    # zero retention, so this run does not add a ghost of its own to the pile.
    live = [s["name"].lower() for s in rows(cur, f"SHOW SCHEMAS IN DATABASE {DATABASE}")]
    if DEMO in live:
        print(f"[demo] {DEMO_SCHEMA} is live — taking it down without leaving a ghost")
        drop_externals(cur)
        cur.execute(f"ALTER SCHEMA {DEMO_SCHEMA} SET DATA_RETENTION_TIME_IN_DAYS = 0")
        cur.execute(f"DROP SCHEMA {DEMO_SCHEMA} CASCADE")
        print(f"[demo]   dropped {DEMO_SCHEMA} (retention 0)")

    # Now peel the ghosts left by every earlier CASCADE.
    for peel in range(1, MAX_PEELS + 1):
        remaining = demo_ghosts(cur)
        if not remaining:
            break
        print(f"[demo] {remaining} ghost(s) of {DEMO} in Time Travel — peeling (pass {peel})")

        # UNDROP restores the most recently dropped one. Make it live so its external table can
        # be deleted for real, then drop it with no retention so it cannot come back.
        cur.execute(f"UNDROP SCHEMA {DEMO_SCHEMA}")
        drop_externals(cur)
        cur.execute(f"ALTER SCHEMA {DEMO_SCHEMA} SET DATA_RETENTION_TIME_IN_DAYS = 0")
        cur.execute(f"DROP SCHEMA {DEMO_SCHEMA} CASCADE")
        print(f"[demo]   peeled one; {demo_ghosts(cur)} left")

    # Assert, do not assume. The provider's error names the stage and never the thing holding
    # it, so a silent miss here costs another full destroy run to diagnose.
    left = demo_ghosts(cur)
    if left:
        con.close()
        sys.exit(f"drop_demo: {left} ghost(s) of {DEMO} still in Time Travel — DROP STAGE would fail")

    print("[demo] no external table, live or recoverable; terraform can drop the stages")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
