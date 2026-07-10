#!/usr/bin/env python3
"""Apply the Azure SQL source-system seed.

Why this exists rather than a `sqlcmd` one-liner: the GitHub runner image does not
ship the mssql tools, and the database is a serverless SKU with a 60-minute
auto-pause. The first connection after an idle period wakes it, and that takes
about a minute, during which every connect attempt is refused. So: retry.

Configured entirely through the environment (no secrets on the command line).

    SQL_SERVER    <name>.database.windows.net
    SQL_DATABASE  sqldb-product-catalog
    SQL_USER      sql_vault_admin
    SQL_PASSWORD  from Key Vault
"""

import os
import sys
import time

import pymssql

SEED = "pipelines/sources/azure_sql/seed.sql"
MAX_ATTEMPTS = 10
BACKOFF_SECONDS = 20


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"apply_seed: missing required env var {name}")
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
            print(f"[seed] attempt {attempt}/{MAX_ATTEMPTS}: {exc}")
            if attempt == MAX_ATTEMPTS:
                sys.exit("apply_seed: the database never became reachable")
            print(f"[seed] serverless database is probably resuming; retrying in {BACKOFF_SECONDS}s")
            time.sleep(BACKOFF_SECONDS)


def main() -> int:
    sql = open(SEED).read()

    conn = connect()
    conn.autocommit(True)
    cur = conn.cursor()

    # The whole file is one T-SQL batch. Deferred name resolution means a table can
    # be created and inserted into within it; the leading `;` on each WITH clause
    # is what keeps the statements separable.
    cur.execute(sql)
    while cur.nextset():
        pass

    cur.execute(
        "SELECT (SELECT COUNT(*) FROM inventory.stock),"
        "       (SELECT COUNT(*) FROM orders.purchase_orders),"
        "       (SELECT COUNT(*) FROM orders.purchase_orders WHERE market IS NULL),"
        "       (SELECT COUNT(*) FROM orders.purchase_orders WHERE units <= 0)"
    )
    stock, pos, null_market, returns = cur.fetchone()
    print(f"[seed] inventory.stock          {stock}")
    print(f"[seed] orders.purchase_orders   {pos}")
    print(f"[seed]   of which null market   {null_market}")
    print(f"[seed]   of which returns       {returns}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
