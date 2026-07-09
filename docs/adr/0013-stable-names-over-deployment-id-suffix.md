# ADR-0013: Stable resource names instead of a rotating `deployment_id` suffix

- **Status:** Accepted
- **Date:** 2026-07-08
- **Supersedes:** the `deployment_id_*` mechanism noted in the ARCHITECTURE before/after table

## Context

Earlier the platform injected a per-deployment 8-character hex suffix
(`deployment_id_aws/azure/gcp`, held in `config.hcl`) into **every** Databricks
object name and storage path — catalogs, external locations, storage credentials,
and the S3/ADLS/GCS folder each layer wrote to.

The suffix existed to work around one Databricks behaviour: after a `destroy`,
some control-plane objects linger briefly in a **soft-deleted** state, so
re-creating the *same* name too soon can collide. The suffix sidestepped that by
giving every re-deploy fresh names — but at a cost:

- **Names became noise.** `loc_sales_raw_0d760a68` instead of `loc_sales_raw` —
  harder to read, reference, document, and reason about.
- **Rotation was manual.** Re-deploy after a destroy required hand-editing the
  hex in `config.hcl` — an un-automated, easy-to-forget step.
- It suffixed *everything*, which is not how names are managed in a stable
  environment. Unique suffixes are standard for globally-unique names (buckets)
  and ephemeral/preview environments — not for a platform that is created once
  and kept.

## Decision

Remove the `deployment_id` suffix entirely and use **stable, meaningful names**
derived from the domain config:

- External-location names come from `location_name` (already unique per domain);
  storage paths come from each location's own `path` (already unique per zone) —
  so nothing depends on a suffix for uniqueness.
- Deleted `deployment_id_*` from both `config.hcl`s, from the six
  `data_platform` terragrunt leaves that passed them, and from the storage-
  credential / `dbx_governance` modules (names + paths) across AWS, Azure, GCP.

## Consequences

**Benefits**
- Production-correct, human-readable names; idempotent applies; nothing to rotate.
- One fewer manual step and one fewer piece of config entropy.

**Trade-off (the honest one)**
- The soft-delete collision the suffix used to hide is now handled at its source:
  if a *just-destroyed* Databricks object is still soft-deleted, re-deploying its
  stable name can hit a transient collision. Mitigation: wait for the soft-delete
  to purge, or purge it via the Databricks API, then re-apply. For the platform's
  own lifecycle (deploy → record → destroy) this is a non-issue: the first deploy
  of a stable name is always clean.
- A fully automated destroy-time purge (so re-deploys never wait) is a reasonable
  follow-up, but it is Databricks-specific and best implemented and **tested**
  against a live account rather than added blind.

## Alternatives considered

- **Auto-generate the suffix (`random_id` shared via an upstream layer).** Keeps
  the workaround but removes the manual rotation. Rejected: still leaves noisy
  names; the real goal was stable names, not a nicer workaround.
- **Keep the manual suffix.** Rejected: not how a lasting environment is named,
  and the manual rotation is the least professional part.
