#!/usr/bin/env bash
# Run one command on the sql-gateway image, as a one-shot ECS task inside the AWS VPC that
# bridges to Azure SQL over the VPN. Azure private mode only.
#
#     azure-sql-task.sh sql "IF SCHEMA_ID('inventory') IS NULL EXEC('CREATE SCHEMA inventory');"
#     azure-sql-task.sh seed
#
# In private mode Azure SQL has no public endpoint, so its schema DDL and seed cannot run from a
# GitHub runner. They run from the one place already able to reach it: the transit gateway's own
# VPC, which resolves the Azure SQL FQDN across the VPN via the Route53 zone. The task borrows the
# running gateway service's network configuration so the two never drift.
#
# The SQL admin password lives in Azure Key Vault, not AWS Secrets Manager, so it cannot be an
# ECS `secrets` entry. This script (which has Azure creds in CI) fetches it and passes it as a
# task-override env var — masked in the CI log, on a short-lived one-shot task, for a simulated
# source system (ADR-0014).
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: azure-sql-task.sh <command> [args...]" >&2; exit 2; }

ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER="sql-gateway-cluster-${ENVIRONMENT}"
SERVICE="sql-gateway-service"
FAMILY="sql-gateway"
CONTAINER="haproxy"
LOG_GROUP="/ecs/sql-gateway-${ENVIRONMENT}"
DB_NAME="${SQL_DATABASE:-sqldb-product-catalog}"
DB_USER="${SQL_USER:-sql_vault_admin}"

# The Azure SQL FQDN and admin password, from Azure.
SRV="$(az sql server list --query "[0].name" -o tsv)"
[ -n "$SRV" ] || { echo "::error::no Azure SQL server found"; exit 1; }
FQDN="${SRV}.database.windows.net"
KV="$(az keyvault list --query "[0].name" -o tsv)"
PW="$(az keyvault secret show --vault-name "$KV" --name sql-admin-password --query value -o tsv)"
echo "::add-mask::$PW"

echo "::notice::running inside the VPC against ${FQDN}: ${*}"

NETCFG="$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].networkConfiguration' --output json)"
if [ "$NETCFG" = "null" ] || [ -z "$NETCFG" ]; then
  echo "::error::no running sql-gateway service in ${CLUSTER} — is Azure private deployed?"
  exit 1
fi

OVERRIDES="$(jq -nc \
  --arg c "$CONTAINER" --arg host "$FQDN" --arg db "$DB_NAME" \
  --arg user "$DB_USER" --arg pw "$PW" \
  --args \
  '{containerOverrides:[{
      name:$c,
      command:$ARGS.positional,
      environment:[
        {name:"TARGET_HOST",value:$host},
        {name:"DB_NAME",value:$db},
        {name:"DB_USER",value:$user},
        {name:"DB_PASSWORD",value:$pw}
      ]
   }]}' "$@")"

TASK="$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$FAMILY" \
  --launch-type FARGATE \
  --network-configuration "$NETCFG" \
  --overrides "$OVERRIDES" \
  --query 'tasks[0].taskArn' --output text)"

echo "  task: ${TASK}"
aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK"

EXIT_CODE="$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" \
  --query 'tasks[0].containers[0].exitCode' --output text)"
STOPPED_REASON="$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" \
  --query 'tasks[0].stoppedReason' --output text)"

echo "  --- container log ---"
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "ecs/${CONTAINER}/${TASK##*/}" \
  --query 'events[].message' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/  /' \
  || echo "  (no log stream)"

if [ "$EXIT_CODE" != "0" ]; then
  echo "::error::task exited ${EXIT_CODE} (${STOPPED_REASON})"
  exit 1
fi
