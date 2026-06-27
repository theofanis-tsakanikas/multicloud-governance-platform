# ADR-0010: `dev`/`prod` as file-for-file config mirrors

- **Status:** Accepted
- **Date:** 2025-06-22

## Context

The platform needs more than one environment, but environments must not diverge in
*architecture* — only in *values* (account IDs, regions, sizes, deployment
suffixes, connectivity mode). A common failure mode is `prod` quietly growing
extra resources or different wiring than `dev`, so a change validated in `dev`
behaves differently in `prod`.

## Decision

Make `environments/dev/` and `environments/prod/` **file-for-file mirrors**. Every
layer reads its values from the nearest `config.hcl`; the only difference between
environments is that file. Promotion is a config diff, not an architecture change.
Targets select the environment via `ENV` (`make plan-aws ENV=prod`, default `dev`).

## Consequences

- A structural change must be made in both trees, so they cannot silently
  diverge — and a reviewer can diff the two `config.hcl`s to see the entire
  environment delta.
- `prod` inherits every layer, gotcha, and guard `dev` has, including the offline
  governance gate.
- Duplicated directory structure is the cost; it is intentional and kept honest by
  the mirror discipline (and could later be DRY'd with a shared include if it
  earns its keep).

## Alternatives considered

- **Terraform workspaces for environments** — rejected: hides the environment
  delta in state rather than making it a visible config diff.
- **A single env with runtime branching** — rejected: branching logic scattered
  across layers is exactly the divergence risk we want to remove.
