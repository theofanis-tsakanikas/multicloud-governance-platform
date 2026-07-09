# ADR-0008: One `is_private_connection` toggle for the whole platform

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

The platform must support both a simple public-connectivity mode (for dev / quick
evaluation) and a fully private mode (NCC/PrivateLink on AWS, Private Endpoints +
VNet peering on Azure, a VPN bridge on GCP) for production. These differ across
all three clouds in networking, workspace creation, and proxy infrastructure.
Without a single control, switching modes would mean coordinated edits in many
places — easy to get half-applied.

## Decision

Expose **one** boolean in `config.hcl`, `is_private_connection`, that switches the
entire platform between public and private connectivity. Layers that only exist in
private mode (`dbx_workspace`, the NLB/PgBouncer proxy, NCC rules) gate themselves
with `for_each = local.private_mode` and become no-ops when it is `false`.

## Consequences

- Public ↔ private is a one-line config change, not a multi-file refactor.
- In public mode the platform uses the serverless workspace from bootstrap, and
  the private-only layers create nothing — so `make apply-azure` finishing quickly
  with no `dbx_workspace` resources is expected behaviour (documented as a gotcha).
- Each cloud's private path is independently implemented behind the same flag, so
  the toggle's meaning is consistent even though the mechanism differs per cloud.

## Alternatives considered

- **Separate public/private environment trees** — rejected: duplicates the whole
  config and invites drift between them.
- **Per-layer flags** — rejected: many flags to keep consistent; one platform-wide
  switch is the right altitude for this decision.
