# ADR-0002: Fetch secrets via `run_cmd` at plan time, never store them

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

The platform needs several secrets at plan/apply time: the Databricks service
principal, RDS/SQL passwords, and per-cloud bootstrap seed credentials. The
options for getting them to Terraform are: commit them (never), pass them as
environment variables / `tfvars` (leaks into shell history, CI logs, state), or
fetch them on demand from a secret manager.

## Decision

Fetch every secret at plan time inside a Terragrunt `locals` block via `run_cmd`,
shelling out to the cloud CLI (`aws secretsmanager get-secret-value`,
`az keyvault secret show`, `gcloud secrets versions access`). Nothing secret is
committed, and nothing is passed through environment variables.

## Consequences

- No secret is ever in the repo, in a `tfvars` file, or injected as an env var.
- The runner needs read access to the secret store — in CI via an OIDC-assumed
  role, locally via the active cloud profile.
- Azure and GCP **seed** credentials live in **AWS** Secrets Manager, because
  bootstrap must authenticate to those clouds before their own secret stores
  exist. Consequence: AWS credentials are required even for Azure/GCP-only layers
  that use seed credentials (documented as a gotcha).
- Secrets can still land in Terraform **state** if a resource stores them;
  state is therefore encrypted at rest (see [ADR-0004](0004-remote-state-s3-dynamodb.md)).

## Alternatives considered

- **`TF_VAR_*` environment variables** — rejected: leaks into process listings and
  CI logs, and couples the deploy to shell setup.
- **`tfvars` files** — rejected: too easy to commit by accident; `.gitignore`'d but
  fragile.
- **Vault provider** — viable, but adds an operational dependency the cloud-native
  secret stores already cover.
