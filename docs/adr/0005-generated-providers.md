# ADR-0005: Generate provider/backend blocks, never commit them

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

Each layer needs `provider` and `backend` configuration, and several providers
(notably Databricks) must be configured with values only known at apply time —
e.g. the `workspace_url` output by the bootstrap layer. Committing static
`provider.tf`/`backend.tf` files would either hardcode those values or duplicate
them across dozens of layers.

## Decision

Keep `infra/` modules pure: only `resource`, `variable`, and `output` blocks — no
providers, no backends. Generate `provider.tf` (and the backend) at plan time with
Terragrunt `generate {}` blocks in each `environments/*/<layer>/terragrunt.hcl`,
wiring live `dependency {}` outputs into the provider config.

## Consequences

- Modules are reusable and testable in isolation — nothing environment-specific is
  baked in.
- Provider config can consume live outputs (workspace URL, account host) without a
  manual edit between applies.
- The generated `provider.tf` is a build artifact, not source — readers must look
  at the `terragrunt.hcl` `generate` block to see provider config, not the module.
- Security scanners (Checkov/tfsec) run against `infra/` only; the generated
  wiring in `environments/` contains no resources to scan (documented as a gotcha).

## Alternatives considered

- **Committed `provider.tf` per layer** — rejected: can't consume apply-time
  outputs; massive duplication.
- **A shared provider module `include`d everywhere** — partial solution, but still
  can't inject per-layer dependency outputs as cleanly as `generate`.
