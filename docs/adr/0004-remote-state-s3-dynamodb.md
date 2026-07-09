# ADR-0004: Remote state in S3 with DynamoDB locking

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

The previous version kept local `.tfstate` files — unshareable, unlockable, and a
data-loss risk. A multi-cloud platform applied from CI and from several engineers'
machines needs one authoritative state per layer, with concurrent-apply
protection.

## Decision

Configure remote state once, globally, in the root `terragrunt.hcl`: an S3 backend
with a DynamoDB lock table, `encrypt = true`, and a state key derived from the
directory hierarchy via `path_relative_to_include()`. No child layer declares a
backend.

```hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "dbx-platform-tfstate-${local.cfg.aws_account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    dynamodb_table = "dbx-platform-tfstate-lock"
    encrypt        = true
  }
}
```

## Consequences

- One state object per layer, keyed automatically by its path — no manual key
  management, no collisions.
- DynamoDB lock prevents concurrent applies from corrupting state.
- Encryption at rest covers any secret that a resource happens to persist into
  state (see [ADR-0002](0002-secrets-via-run-cmd-at-plan-time.md)).
- The state bucket + lock table are a bootstrap prerequisite that lives outside
  the managed stacks.

## Alternatives considered

- **Terraform Cloud / HCP** — viable, but adds an external dependency and cost; S3
  is already in the AWS footprint we manage.
- **Per-layer hand-written backends** — rejected: repetitive and easy to get
  inconsistent; the root `generate` approach keeps it DRY.
