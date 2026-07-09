# ADR-0003: Single-phase IAM with a static `external_id`

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

Databricks cross-account access on AWS uses an IAM role with a trust policy that
names a trust principal and an `external_id` (the confused-deputy guard). The
previous design provisioned this in two phases driven by an
`is_initial_deployment = true/false` flag, because it believed the `external_id`
was only known after the first apply — a chicken-and-egg dance that made the IAM
layer stateful and error-prone.

## Decision

Use the AWS Account ID — a constant known at design time — as the `external_id`.
Set both trust principals in a single `terraform apply`. Delete the
`is_initial_deployment` flag and the two-phase path entirely.

```hcl
external_id = var.aws_account_id  # known constant — no chicken-and-egg problem
```

## Consequences

- The IAM layer is idempotent and stateless across runs — no "first vs subsequent
  apply" mode to track or get wrong.
- One fewer flag in `config.hcl` and one fewer branch in the IAM module.
- The `external_id` is not secret (it never was — it's an anti-confused-deputy
  nonce, and the account ID serves that role fine within our trust boundary).

## Alternatives considered

- **Keep the two-phase flag** — rejected: complexity with no security benefit.
- **Random/generated `external_id` stored in state** — rejected: reintroduces the
  ordering problem and a value to manage, for no gain over the account ID.
