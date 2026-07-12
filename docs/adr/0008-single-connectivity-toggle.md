# ADR-0008: One `is_private_connection` toggle for the whole platform

- **Status:** **Superseded by the code** — see the amendment at the bottom
- **Date:** 2025-05-31

> **⚠️ This ADR no longer describes the platform.** It is kept because a decision ledger that
> quietly deletes the decisions it outgrew is not a ledger. The record of what changed, and why,
> is at the end of the file.

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

---

## Amendment (2026-07-13) — what the code actually does now

Two claims above are false, and both were falsified by building the thing.

**1. There is not one toggle. There are three.**

```hcl
# environments/dev/config.hcl
is_private_connection_aws   = get_env("PRIVATE_AWS",   "false") == "true"
is_private_connection_azure = get_env("PRIVATE_AZURE", "false") == "true"
is_private_connection_gcp   = get_env("PRIVATE_GCP",   "false") == "true"
```

`dbx-deploy.yml` exposes each cloud as a tri-state `skip | public | private`. A single global flag
could not express the state the platform actually spent most of its life in: one cloud private while
the other two stayed public, because private mode costs roughly $18/day and there is no reason to pay
it on a cloud you are not currently working on. The per-cloud flag was not a refinement of this
decision — it was a correction of it.

**2. `dbx_workspace` is not gated by connectivity mode.**

The original text names `dbx_workspace` as one of the layers this toggle switches. It is not. The
workspace is created once, in `bootstrap/`, with `compute_mode = SERVERLESS`, and it is the *same*
workspace in both modes. Connectivity changes how that workspace *reaches* its data — NCC rules,
PrivateLink, transit hubs — not whether it exists.

**What the flag actually gates**, per cloud, is: the whole `integration` layer (the transit hub), the
ECR repository and the gateway image, the transit VPC and its VPN gateway, the private endpoint, and
the `publicly_accessible` / `publicNetworkAccess` field on the database. In public mode those modules
receive `for_each = {}` and the plan is *empty* — not "created and ignored".

**The mechanism the ADR chose was right; only its scope was wrong.** `local.private_mode =
var.is_private_connection ? { "enabled" = true } : {}` + `for_each` is still exactly how every gated
module works. It was simply applied three times instead of once.
