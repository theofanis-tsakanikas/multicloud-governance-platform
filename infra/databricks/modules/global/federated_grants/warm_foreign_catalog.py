#!/usr/bin/env python3
"""Force Unity Catalog to discover the schemas of a FOREIGN (federated) catalog.

Why this exists
---------------
A foreign catalog holds no metadata of its own — its schemas live in the remote
engine (Postgres / SQL Server / BigQuery). Unity Catalog materialises that
metadata lazily, and *only* when a compute resource actually queries the
catalog. Until then:

    GET /unity-catalog/schemas?catalog_name=<fed>   -> {}            (empty)
    PATCH /unity-catalog/permissions/schema/<fed>.x -> 404 not found

which surfaces from Terraform as:

    Error: cannot create grants: Schema '<fed>.<schema>' does not exist.

Listing via the REST API does *not* trigger discovery (verified: six consecutive
list calls on a fresh foreign catalog returned zero schemas). Running a single
`SHOW SCHEMAS` on a SQL warehouse does, and the result then persists — including
after the warehouse stops.

So: before applying per-schema grants we run one `SHOW SCHEMAS` and block until
every schema the domain model declares is visible.

Configured entirely through the environment (no secrets on the command line).
"""

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

TOKEN_TIMEOUT = 30
STATEMENT_TIMEOUT = 60
# A cold serverless warehouse takes ~30s to start; the statement API waits at
# most 50s, so poll a few times rather than assuming the first call finishes.
MAX_ATTEMPTS = 8
BACKOFF_SECONDS = 10


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"warm_foreign_catalog: missing required env var {name}")
    return value


def post(url: str, token: str, payload: dict, timeout: int) -> dict:
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def get(url: str, token: str, timeout: int) -> dict:
    req = urllib.request.Request(url, method="GET")
    req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def oauth_token(host: str, client_id: str, client_secret: str) -> str:
    data = urllib.parse.urlencode(
        {"grant_type": "client_credentials", "scope": "all-apis"}
    ).encode()
    req = urllib.request.Request(f"{host}/oidc/v1/token", data=data, method="POST")
    basic = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    req.add_header("Authorization", f"Basic {basic}")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req, timeout=TOKEN_TIMEOUT) as resp:
        return json.load(resp)["access_token"]


def show_schemas(host: str, token: str, warehouse_id: str, catalog: str) -> set:
    """Run SHOW SCHEMAS on the warehouse and return the discovered schema names."""
    result = post(
        f"{host}/api/2.0/sql/statements",
        token,
        {
            "warehouse_id": warehouse_id,
            "statement": f"SHOW SCHEMAS IN `{catalog}`",
            "wait_timeout": "50s",
            "on_wait_timeout": "CONTINUE",
        },
        STATEMENT_TIMEOUT,
    )

    statement_id = result.get("statement_id")
    state = result.get("status", {}).get("state")

    # The warehouse may still be starting — poll the statement to completion.
    while state in ("PENDING", "RUNNING") and statement_id:
        time.sleep(5)
        result = get(f"{host}/api/2.0/sql/statements/{statement_id}", token, STATEMENT_TIMEOUT)
        state = result.get("status", {}).get("state")

    if state != "SUCCEEDED":
        error = result.get("status", {}).get("error", {})
        raise RuntimeError(f"SHOW SCHEMAS state={state} error={error}")

    rows = result.get("result", {}).get("data_array") or []
    return {row[0] for row in rows if row}


def main() -> int:
    host = env("DBX_HOST").rstrip("/")
    catalog = env("DBX_CATALOG")
    warehouse_id = env("DBX_WAREHOUSE_ID")
    expected = {s for s in env("DBX_EXPECTED_SCHEMAS").split(",") if s}

    token = oauth_token(host, env("DBX_CLIENT_ID"), env("DBX_CLIENT_SECRET"))

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            found = show_schemas(host, token, warehouse_id, catalog)
        except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as exc:
            print(f"[warm] {catalog}: attempt {attempt}/{MAX_ATTEMPTS} failed: {exc}")
            if attempt == MAX_ATTEMPTS:
                raise
            time.sleep(BACKOFF_SECONDS)
            continue

        missing = expected - found
        if not missing:
            print(f"[warm] {catalog}: discovered {sorted(found)} — grants can now apply")
            return 0

        print(
            f"[warm] {catalog}: attempt {attempt}/{MAX_ATTEMPTS} — "
            f"still missing {sorted(missing)} (saw {sorted(found)})"
        )
        time.sleep(BACKOFF_SECONDS)

    sys.exit(
        f"warm_foreign_catalog: {catalog} never exposed {sorted(expected)}. "
        "Check that the remote schemas exist and the connection credentials are valid."
    )


if __name__ == "__main__":
    sys.exit(main())
