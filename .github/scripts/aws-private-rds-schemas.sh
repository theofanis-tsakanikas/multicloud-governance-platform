#!/usr/bin/env bash
# Create the federated catalog's schemas from inside the VPC. Private mode only.
#
# `storage/rds_schemas` creates nothing in private mode — a private RDS has no public address
# and admits only the gateway's security group, so Terraform has nothing to connect over (see
# infra/aws/modules/storage/rds_schemas/main.tf). The schemas are made here instead, by the one
# thing that *is* in the network: a one-shot task on the gateway image.
#
# Runs between `integration` (which stands the cluster up) and `data_platform` (whose federated
# grants warm the foreign catalog, and need the schemas to exist to find anything).
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

# The schemas come from the domain contract, not from a list in this file. The FEDERATED catalog
# declares them; a schema added to the JSON arrives here without anyone having to remember.
SQL="$(python3 - "$ENVIRONMENT" <<'PY'
import json, sys
env = sys.argv[1]
d = json.load(open(f"environments/{env}/domains/aws/sales_infra.json"))
names = [s["schema_name"]
         for c in d["catalogs"] if c["type"] == "FEDERATED"
         for s in c.get("schemas", [])]
if not names:
    sys.exit("no FEDERATED schemas declared in sales_infra.json")
print("; ".join(f"CREATE SCHEMA IF NOT EXISTS {n}" for n in names) + ";")
PY
)"

echo "::notice::creating the federated catalog's schemas: ${SQL}"
exec "$(dirname "$0")/aws-rds-task.sh" sql "$SQL"
