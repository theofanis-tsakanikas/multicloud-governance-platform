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

    SNOWFLAKE_ACCOUNT / SNOWFLAKE_USER / SNOWFLAKE_ROLE, plus either SNOWFLAKE_PRIVATE_KEY
    (key-pair, preferred — survives account MFA) or SNOWFLAKE_PASSWORD (fallback).
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


def undrop_demo(cur) -> bool:
    """Restore the most recent ghost. False once there is nothing recoverable left.

    The termination signal, and it has to be this one. SHOW SCHEMAS HISTORY is NOT a count of
    ghosts: it keeps listing a dropped schema after its Time Travel is gone, so a run that
    peeled every ghost still sees the same number and loops forever. Only UNDROP knows the
    difference between a schema that can come back and a row that merely remembers one.
    """
    try:
        cur.execute(f"UNDROP SCHEMA {DEMO_SCHEMA}")
        return True
    except Exception as exc:
        if "did not exist" in str(exc) or "purged" in str(exc):
            return False
        raise


def drop_externals(cur) -> None:
    """Explicitly, by name. A CASCADE would only Time-Travel them."""
    for t in rows(cur, f"SHOW EXTERNAL TABLES IN DATABASE {DATABASE}"):
        fqn = f'"{t["database_name"]}"."{t["schema_name"]}"."{t["name"]}"'
        cur.execute(f"DROP EXTERNAL TABLE IF EXISTS {fqn}")
        print(f"[demo]   dropped external table {fqn}")


def _connect():
    """Prefer key-pair (JWT) auth; fall back to password.

    The Terraform provider moved to key-pair because an MFA-enforcing account rejects password
    auth in a non-interactive run (ADR-0016: 394508 "MFA with TOTP is required"). This connector
    runs against the same account in the same teardown, so it needs the same key — SNOWFLAKE_
    PASSWORD alone would fail exactly where the destroy cannot afford to. Password is kept as a
    fallback for a forked account that does not enforce MFA.
    """
    common = dict(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        login_timeout=30,
    )
    pem = os.environ.get("SNOWFLAKE_PRIVATE_KEY")
    if pem:
        # snowflake-connector-python wants the key as DER bytes, not PEM text.
        from cryptography.hazmat.primitives import serialization

        key = serialization.load_pem_private_key(pem.encode(), password=None)
        der = key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )
        return snowflake.connector.connect(private_key=der, **common)
    return snowflake.connector.connect(password=os.environ["SNOWFLAKE_PASSWORD"], **common)


def main() -> int:
    try:
        con = _connect()
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

    # Now peel the ghosts left by every earlier CASCADE, newest first, until UNDROP says there
    # are none — which is the only trustworthy way to ask.
    peeled = 0
    for _ in range(MAX_PEELS):
        if not undrop_demo(cur):
            break
        peeled += 1
        print(f"[demo] restored a ghost of {DEMO} (pass {peeled}) — deleting it for real")
        drop_externals(cur)
        cur.execute(f"ALTER SCHEMA {DEMO_SCHEMA} SET DATA_RETENTION_TIME_IN_DAYS = 0")
        cur.execute(f"DROP SCHEMA {DEMO_SCHEMA} CASCADE")
    else:
        con.close()
        sys.exit(f"drop_demo: still peeling ghosts after {MAX_PEELS} passes — something is regenerating them")

    # Assert, do not assume: one more UNDROP must fail. The provider's error names the stage and
    # never the thing holding it, so a silent miss here costs another full destroy run to find.
    if undrop_demo(cur):
        con.close()
        sys.exit(f"drop_demo: {DEMO} is still recoverable — terraform's DROP STAGE would fail")

    print(f"[demo] {peeled} ghost(s) peeled; nothing recoverable remains")
    print("[demo] no external table, live or in Time Travel; terraform can drop the stages")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
