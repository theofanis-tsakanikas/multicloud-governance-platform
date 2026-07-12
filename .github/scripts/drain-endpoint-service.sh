#!/usr/bin/env bash
# Reject the endpoint connections into ONE cloud's PrivateLink service, so AWS will let it go.
#
#     drain-endpoint-service.sh aws|azure|gcp
#
# ── WHY THIS EXISTS ────────────────────────────────────────────────────────────────────────────
#
# Terraform deletes the NCC rule and Databricks drops it from its config at once — then leaves its
# actual VPC endpoint standing, in its own AWS account, still connected to our endpoint service.
# AWS will not delete a service that has a live connection:
#
#     Error: deleting EC2 VPC Endpoint Service (vpce-svc-...): ... has active connections
#
# Waiting does not win this. Twenty minutes after the rule was gone, the endpoint was still
# `available`. But a connection has two ends, and the service owner may reject one — and a rejected
# endpoint is one AWS will let go of.
#
# The gateway modules carry a null_resource that does this in-band, on the way out. That only helps
# a stack applied AFTER that resource existed: Terraform runs destroy provisioners for what is in
# the state, and a state written before the fix has no such resource in it. This script is what
# closes that gap — the destroy job calls it when a layer fails, then retries the layer once.
#
# ── WHY IT TAKES A CLOUD, AND IS NOT ALLOWED TO GUESS ──────────────────────────────────────────
#
# There are three of these services, one per private path, and they are torn down on three separate
# days. Draining all of them because one destroy failed would sever the two private paths that are
# still standing and still in use. So the caller names the cloud, and this touches exactly the one
# service that belongs to it.
set -euo pipefail

CLOUD="${1:?usage: drain-endpoint-service.sh <aws|azure|gcp>}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${AWS_REGION:-eu-central-1}"

case "$CLOUD" in
  aws)   NAME="rds-ncc-service-${ENVIRONMENT}" ;;  # Databricks → RDS Postgres
  azure) NAME="sql-ncc-service-${ENVIRONMENT}" ;;  # Databricks → Azure SQL, over the VPN
  gcp)   NAME="bq-ncc-service-${ENVIRONMENT}"  ;;  # Databricks → BigQuery, over the VPN
  *)     echo "::error::unknown cloud '${CLOUD}'"; exit 2 ;;
esac

SVC="$(aws ec2 describe-vpc-endpoint-service-configurations --region "$REGION" \
        --filters "Name=tag:Name,Values=${NAME}" \
        --query 'ServiceConfigurations[0].ServiceId' --output text 2>/dev/null || true)"

if [ -z "$SVC" ] || [ "$SVC" = "None" ]; then
  echo "::notice::no endpoint service tagged ${NAME} — nothing to drain"
  exit 0
fi

IDS="$(aws ec2 describe-vpc-endpoint-connections --region "$REGION" \
        --filters "Name=service-id,Values=${SVC}" \
        --query 'VpcEndpointConnections[?VpcEndpointState==`available` || VpcEndpointState==`pendingAcceptance`].VpcEndpointId' \
        --output text)"

if [ -z "$IDS" ]; then
  echo "::notice::${NAME} (${SVC}) has no live endpoint connections — nothing to drain"
  exit 0
fi

echo "::notice::rejecting Databricks' endpoint(s) on ${NAME} (${SVC}): ${IDS}"
# shellcheck disable=SC2086  # IDS is a deliberate word-split list of endpoint ids
aws ec2 reject-vpc-endpoint-connections --region "$REGION" \
  --service-id "$SVC" --vpc-endpoint-ids $IDS >/dev/null

# Rejection is not instant. Give AWS a moment to move them out of `available`, or the retry hits the
# same error and the second failure looks like the fix did not work.
for _ in $(seq 1 12); do
  LEFT="$(aws ec2 describe-vpc-endpoint-connections --region "$REGION" \
            --filters "Name=service-id,Values=${SVC}" \
            --query 'VpcEndpointConnections[?VpcEndpointState==`available`].VpcEndpointId' \
            --output text)"
  [ -z "$LEFT" ] && { echo "::notice::${NAME} is clear — the service can be deleted now"; exit 0; }
  sleep 5
done

echo "::warning::${NAME} still shows a live connection after 60s; retrying the layer anyway"
