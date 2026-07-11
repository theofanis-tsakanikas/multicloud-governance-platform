#!/usr/bin/env bash
# Create the federated catalog's schemas in Azure SQL, from inside the VPC. Azure private only.
#
# The mssql_schemas Terraform layer is a no-op in private mode (a private SQL server is
# unreachable from CI). The schemas are created here instead, by a one-shot task on the transit
# gateway — the mirror of the AWS aws-private-rds-schemas.sh.
#
# Runs between `integration` (which stands the gateway up) and `data_platform` (whose federated
# grants warm the foreign catalog and need the schemas to exist).
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

# From the domain contract, not a list in this file. CREATE SCHEMA must be the only statement in
# its batch, so each is wrapped in EXEC() and guarded by SCHEMA_ID for idempotency — that lets
# them all run in one batch and re-run safely.
SQL="$(python3 - "$ENVIRONMENT" <<'PY'
import json, sys
env = sys.argv[1]
d = json.load(open(f"environments/{env}/domains/azure/supply_infra.json"))
names = [s["schema_name"]
         for c in d["catalogs"] if c["type"] == "FEDERATED"
         for s in c.get("schemas", [])]
if not names:
    sys.exit("no FEDERATED schemas declared in supply_infra.json")
print(" ".join(f"IF SCHEMA_ID('{n}') IS NULL EXEC('CREATE SCHEMA {n}');" for n in names))
PY
)"

echo "::notice::creating the federated catalog's schemas: ${SQL}"
exec "$(dirname "$0")/azure-sql-task.sh" sql "$SQL"
