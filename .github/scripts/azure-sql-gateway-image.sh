#!/usr/bin/env bash
# Build the Azure SQL transit-gateway image and push it to ECR. Azure private mode only.
#
# The twin of aws-private-gateway-image.sh. The integration layer's ECS service references
# <acct>.dkr.ecr.<region>.amazonaws.com/sql-gateway:latest; nothing else builds it, and the
# service waits for steady state — so a missing image fails the deploy loudly rather than
# crash-looping behind a green apply.
#
# Runs between `network` (which creates the ECR repository, inside aws_network) and `integration`
# (which creates the ECS service that pulls the image).
set -euo pipefail

REGION="${AWS_REGION:?AWS_REGION is required}"
REPO="${ECR_REPO:?ECR_REPO is required}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}:latest"

echo "::notice::building the Azure SQL transit-gateway image -> ${IMAGE}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# Build context is the repo root: the image bakes the Azure source-system seed
# (pipelines/sources/azure_sql/seed.sql) for the `seed` role.
docker build --file docker/sql-gateway/Dockerfile --tag "$IMAGE" .
docker push "$IMAGE"

echo "::notice::pushed ${IMAGE}"
