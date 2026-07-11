#!/usr/bin/env bash
# Build the BigQuery transit-gateway image and push it to ECR. GCP private mode only.
#
# The third of three, and the same shape as the other two: the integration layer's ECS service
# references <acct>.dkr.ecr.<region>.amazonaws.com/bq-gateway:latest, nothing else builds it, and
# the service waits for steady state — so a missing image fails the deploy loudly instead of
# crash-looping behind a green apply.
#
# Runs between `network` (which creates the ECR repository inside GCP's own AWS transit VPC) and
# `integration` (which creates the ECS service that pulls the image).
set -euo pipefail

REGION="${AWS_REGION:?AWS_REGION is required}"
REPO="${ECR_REPO:?ECR_REPO is required}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}:latest"

echo "::notice::building the BigQuery transit-gateway image -> ${IMAGE}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker build --file docker/bq-gateway/Dockerfile --tag "$IMAGE" .
docker push "$IMAGE"

echo "::notice::pushed ${IMAGE}"
