#!/usr/bin/env bash
# Build the RDS gateway image and push it to ECR. Private mode only.
#
# The ECS task definition has always referenced `<acct>.dkr.ecr.<region>.amazonaws.com/
# pgbouncer-gateway:latest`. Nothing ever built it. Terraform would apply green, the task would
# crash-loop on CannotPullContainerError, the target group would never go healthy, and the whole
# private path was dead behind a successful deploy — the worst kind of failure, the silent one.
#
# Runs between `foundation` (which creates the ECR repository) and `integration` (which creates
# the ECS service that pulls from it). The service now waits for steady state, so if this step
# is skipped the deploy fails loudly instead of lying.
set -euo pipefail

REGION="${AWS_REGION:?AWS_REGION is required}"
REPO="${ECR_REPO:?ECR_REPO is required}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}:latest"

echo "::notice::building the RDS gateway image -> ${IMAGE}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# Build context is the repo root: the image bakes the source system's seed
# (pipelines/sources/rds/seed.sql), so that the `seed` role can run from inside the VPC — the
# only place a private RDS can be reached from.
docker build --file docker/rds-gateway/Dockerfile --tag "$IMAGE" .
docker push "$IMAGE"

echo "::notice::pushed ${IMAGE}"
