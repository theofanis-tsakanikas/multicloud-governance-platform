#!/usr/bin/env python3
"""Deploy the governance demo as a native Snowflake Notebook.

The Databricks side has its results notebook uploaded by the Asset Bundle; this is
the Snowflake equivalent. It stages governance_demo.ipynb and creates a Snowsight
Notebook over it, so the demo is "open and Run all" rather than copy-paste.

Idempotent: CREATE OR REPLACE NOTEBOOK + a fresh LIVE VERSION each run.

Credentials come from the environment (the pipeline exports them from GitHub
secrets); for a local run, export them yourself or source them from AWS Secrets
Manager the same way every other secret in this repo is read:

    export SNOWFLAKE_ACCOUNT=SNOWFLAKE_LOCATOR_REDACTED
    export SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=... SNOWFLAKE_ROLE=ACCOUNTADMIN

The notebook lives in "sales_aws"."demo" — the ungoverned demo schema, not part
of the domain contract.
"""

import os
import sys
import pathlib
import snowflake.connector

DB = '"sales_aws"'
SCHEMA = '"sales_aws"."demo"'
STAGE = '"sales_aws"."demo"."nb_stage"'
NOTEBOOK = '"sales_aws"."demo"."governance_demo"'
IPYNB = pathlib.Path(__file__).with_name("governance_demo.ipynb")


def main() -> int:
    warehouse = os.environ.get("SNOWFLAKE_WAREHOUSE", "DEV_SALES_WH")
    con = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        warehouse=warehouse,
        login_timeout=30,
    )
    cur = con.cursor()
    steps = [
        ("use database", f"USE DATABASE {DB}"),
        # The demo schema and stage may already exist (Terraform / a prior run);
        # IF NOT EXISTS keeps this safe to re-run.
        ("demo schema", f"CREATE SCHEMA IF NOT EXISTS {SCHEMA} "
                        "COMMENT = 'Not governed by the domain contract. Demo scaffolding only.'"),
        ("stage", f"CREATE STAGE IF NOT EXISTS {STAGE}"),
        ("stage the notebook",
         f"PUT file://{IPYNB.resolve()} @{STAGE} OVERWRITE=TRUE AUTO_COMPRESS=FALSE"),
        ("create notebook",
         f"CREATE OR REPLACE NOTEBOOK {NOTEBOOK} "
         f"FROM '@{STAGE}' MAIN_FILE = '{IPYNB.name}' QUERY_WAREHOUSE = {warehouse}"),
        ("publish a live version",
         f"ALTER NOTEBOOK {NOTEBOOK} ADD LIVE VERSION FROM LAST"),
    ]
    for label, sql in steps:
        cur.execute(sql)
        print(f"  ok  {label}")

    print(f"\nNotebook ready: {NOTEBOOK}  (Snowsight -> Projects -> Notebooks -> governance_demo)")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
