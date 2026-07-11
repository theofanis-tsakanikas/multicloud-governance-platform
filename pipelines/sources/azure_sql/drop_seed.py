#!/usr/bin/env python3
"""Empty the Azure SQL source-system schemas so Terraform can drop them.

The mirror of apply_seed.py, and it exists for a reason Terraform cannot fix.

`DROP SCHEMA` in T-SQL has **no CASCADE**. The AWS side gets away with it because the
postgres provider exposes `drop_cascade` (see infra/aws/modules/storage/rds_schemas, where
dev turns it on); the pgssoft/mssql provider has no equivalent, so `mssql_schema` destroy
fails the moment the schema holds anything:

    mssql: Cannot drop schema 'orders' because it is being referenced by object

The tables are not Terraform's to begin with. The pipeline seeds them (apply_seed.py) into a
SIMULATED source system — ADR-0014 — so the pipeline is what must unseed them. Terraform owns
the schema; the seed owns the rows. Ownership is symmetric, and so is the teardown.

Runs before `terragrunt destroy` in the azure destroy job. Idempotent, and a no-op if the
tables are already gone, so re-running a failed destroy is safe.

    SQL_SERVER    <name>.database.windows.net
    SQL_DATABASE  sqldb-product-catalog
    SQL_USER      sql_vault_admin
    SQL_PASSWORD  from Key Vault
"""

import os
import sys
import time

import pymssql

# The schemas Terraform will drop. Anything inside them belongs to the seed.
SCHEMAS = ("inventory", "orders")
MAX_ATTEMPTS = 10
BACKOFF_SECONDS = 20


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"drop_seed: missing required env var {name}")
    return value


def connect():
    server, database = env("SQL_SERVER"), env("SQL_DATABASE")
    user, password = env("SQL_USER"), env("SQL_PASSWORD")
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            return pymssql.connect(
                server=server, user=user, password=password, database=database,
                timeout=60, login_timeout=60,
            )
        except Exception as exc:  # pymssql raises several distinct types
            print(f"[drop] attempt {attempt}/{MAX_ATTEMPTS}: {exc}")
            if attempt == MAX_ATTEMPTS:
                sys.exit("drop_seed: the database never became reachable")
            print(f"[drop] serverless database is probably resuming; retrying in {BACKOFF_SECONDS}s")
            time.sleep(BACKOFF_SECONDS)


def main() -> int:
    conn = connect()
    conn.autocommit(True)
    cur = conn.cursor()

    # Discover rather than hard-code: the seed may grow a table and this script must not need
    # to be told. Foreign keys first — a referenced table will not drop while a constraint
    # points at it, and the error would be the same class of failure this script exists to end.
    placeholders = ",".join(f"'{s}'" for s in SCHEMAS)

    cur.execute(f"""
        SELECT s.name, t.name, fk.name
        FROM sys.foreign_keys fk
        JOIN sys.tables  t ON t.object_id = fk.parent_object_id
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name IN ({placeholders})
    """)
    for schema, table, fk in cur.fetchall():
        cur.execute(f"ALTER TABLE [{schema}].[{table}] DROP CONSTRAINT [{fk}]")
        print(f"[drop] fk    {schema}.{table}.{fk}")

    # Views before tables, for the same reason.
    for kind, catalog in (("view", "sys.views"), ("table", "sys.tables")):
        cur.execute(f"""
            SELECT s.name, o.name
            FROM {catalog} o
            JOIN sys.schemas s ON s.schema_id = o.schema_id
            WHERE s.name IN ({placeholders})
        """)
        for schema, name in cur.fetchall():
            cur.execute(f"DROP {kind.upper()} [{schema}].[{name}]")
            print(f"[drop] {kind:5s} {schema}.{name}")

    # Prove it: Terraform's DROP SCHEMA only succeeds on an empty schema, and a silent
    # miss here would surface as the same opaque provider error we are here to prevent.
    cur.execute(f"""
        SELECT s.name, COUNT(o.object_id)
        FROM sys.schemas s
        LEFT JOIN sys.objects o ON o.schema_id = s.schema_id
        WHERE s.name IN ({placeholders})
        GROUP BY s.name
    """)
    remaining = cur.fetchall()
    for schema, count in remaining:
        print(f"[drop] {schema}: {count} objects remaining")
    if any(count for _, count in remaining):
        sys.exit("drop_seed: objects remain — terraform's DROP SCHEMA would still fail")

    print("[drop] schemas are empty; terraform can drop them")
    return 0


if __name__ == "__main__":
    sys.exit(main())
