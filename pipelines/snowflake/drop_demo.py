#!/usr/bin/env python3
"""Drop the Snowflake demo scaffolding so Terraform can drop the stages it stands on.

The mirror of read_gold_zone.sql / masking_demo.sql / deploy_notebook.py, and the twin of
pipelines/sources/azure_sql/drop_seed.py — the same lesson, in a different engine.

The AWS destroy died on:

    093694 (42601): Stage loc_sales_gold cannot be dropped or replaced or have its URL
    altered because it has active External table(s) using it.

Terraform owns the stage. It does **not** own the external table sitting on top of it: that is
`"sales_aws"."demo"."executive_cross_cloud"`, created by the demo SQL, over the Parquet the
Databricks medallion exports. Same for the masking demo's `customers` table and its policy, the
notebook, and the stage the notebook was uploaded to. None of it is Terraform's, all of it is in
the ungoverned `demo` schema — which is exactly what that schema's COMMENT says it is:

    'Not governed by the domain contract. Demo scaffolding only.'

So the demo takes its own scaffolding back down, in the destroy job, just before terragrunt —
where the deploy job puts it up. Snowflake, unlike T-SQL, does have DROP SCHEMA ... CASCADE, so
this is one statement rather than a discovery loop.

Idempotent (IF EXISTS), so re-running a failed destroy is safe, and a no-op if the demo was
never deployed.

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

    # The database itself may already be gone (a re-run after a partial destroy). That is a
    # success, not a failure — there is nothing left to clean up.
    try:
        cur.execute(f"USE DATABASE {DATABASE}")
    except Exception as exc:
        print(f"[demo] {DATABASE} is not there ({str(exc)[:60]}) — nothing to drop")
        con.close()
        return 0

    # CASCADE takes the external table, the masking policy and the table it is attached to,
    # the notebook, the notebook's stage and the file format — every object the demo created.
    cur.execute(f"DROP SCHEMA IF EXISTS {DEMO_SCHEMA} CASCADE")
    print(f"[demo] dropped {DEMO_SCHEMA} (cascade)")

    # Prove the blocker is gone rather than assume it. An external table anywhere else in the
    # database would stop the same stage from dropping, and the provider error it raises names
    # the stage, not the table — so find it here, where the message can say which one.
    cur.execute(f"SHOW EXTERNAL TABLES IN DATABASE {DATABASE}")
    leftovers = [f"{r[2]}.{r[3]}.{r[1]}" for r in cur.fetchall()]
    if leftovers:
        print("[demo] external tables still standing on the stages:")
        for t in leftovers:
            print(f"[demo]   {t}")
        con.close()
        sys.exit("drop_demo: terraform's DROP STAGE would still fail")

    print("[demo] no external tables remain; terraform can drop the stages")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
