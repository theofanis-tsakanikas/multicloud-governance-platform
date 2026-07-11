#!/usr/bin/env bash
# Run one command on the RDS gateway image, as a one-shot ECS task inside the VPC.
#
#     aws-rds-task.sh sql "CREATE SCHEMA IF NOT EXISTS crm;"
#     aws-rds-task.sh seed
#
# This exists because in private mode there is no other way in. `publicly_accessible = false`
# leaves the instance with no public address, and its security group admits 5432 from exactly
# one place — the gateway container's own security group. A GitHub runner is not in the VPC.
# There is no firewall rule to add and no address to route to; reaching the database from CI is
# not hard in private mode, it is impossible, and it is impossible on purpose.
#
# So the work moves to where the database is. The gateway image (docker/rds-gateway) carries a
# `sql` role and a `seed` role for precisely this, and the task runs in the same subnets and the
# same security group as the gateway itself — the one door the platform already built.
#
# Both callers — the deploy's schema creation and the pipeline's seed — are the same shape, so
# they share this. The task's network configuration is borrowed from the running gateway service
# rather than re-derived, which keeps the two from ever drifting apart.
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: aws-rds-task.sh <command> [args...]" >&2; exit 2; }

ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER="db-gateway-cluster-${ENVIRONMENT}"
SERVICE="pgbouncer-service"
FAMILY="pgbouncer-gateway"
CONTAINER="pgbouncer"
LOG_GROUP="/ecs/pgbouncer-${ENVIRONMENT}"

echo "::notice::running inside the VPC: ${*}"

NETCFG="$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].networkConfiguration' --output json)"
if [ "$NETCFG" = "null" ] || [ -z "$NETCFG" ]; then
  echo "::error::no running gateway service in ${CLUSTER} — is the stack deployed in private mode?"
  exit 1
fi

OVERRIDES="$(jq -nc --arg c "$CONTAINER" --args '{containerOverrides:[{name:$c,command:$ARGS.positional}]}' "$@")"

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

# Print the container's own words either way. An exit code says whether it died; only the log
# says what it did — and a task that succeeds while doing nothing is exactly the silent failure
# this whole path exists to make impossible.
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
