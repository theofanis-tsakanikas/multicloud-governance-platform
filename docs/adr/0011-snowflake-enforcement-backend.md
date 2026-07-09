# 11. Snowflake as a second enforcement backend (engine-agnostic governance)

Date: 2026-07-03

## Status

Accepted

## Context

The platform's core idea is a **vendor-neutral governance contract**: per-domain JSON
(schemas, classifications, RBAC grants) validated by a deterministic policy gate
(`policy_analyzer.py`) and an independent OPA/Rego re-implementation, *before* anything is
applied. Until now that contract had exactly one enforcement backend — Databricks Unity
Catalog — where the abstract grant privilege happens to *be* the UC privilege (an identity
mapping). That coincidence hid a question: is the governance model genuinely
engine-agnostic, or is it just "UC config with extra steps"?

The way to answer it is to enforce the *same* contract on a *second*, materially different
engine and prove the result is equivalent. Snowflake is the natural choice: a different RBAC
vocabulary (USAGE / SELECT / INSERT vs USE_SCHEMA / SELECT / MODIFY), different object model
(database / schema / stage vs catalog / schema / volume / external location), and it is where
many of the platform's target organisations actually live.

## Decision

Add a **Snowflake enforcement backend** that consumes the identical domain JSON and produces
Snowflake governance, with a single shared translation contract and a provable equivalence
check.

1. **One translation contract.** `infra/snowflake/privilege_map.json` maps each abstract/UC
   privilege to Snowflake privilege(s) plus a *scope* (self / all+future tables). It is read
   by **both** the Snowflake Terraform (`jsondecode` + `lookup`) and the Python consistency
   check (`scripts/snowflake_backend.py`). There is no second source of truth to drift.

2. **Terraform mirrors the UC modules.** `infra/snowflake/modules/global/*` (roles, database,
   schema, external_stage, grants, masking, warehouse_monitor) are cloud-neutral, wrapped by
   `infra/aws/modules/data_platform/snowflake_governance` and wired by a Terragrunt leaf that
   reads the same domain files as `dbx_governance`. Functional roles mirror the UC groups;
   grants are least-privilege (explicit privileges, never `ALL`), with schema-level SELECT /
   MODIFY fanned out to ALL + FUTURE tables (the correct Snowflake pattern); classification
   drives **tag-based masking**; each domain gets a warehouse capped by a **resource monitor**
   (cost governance).

3. **Provable equivalence, not faith.** `scripts/snowflake_backend.py` computes, *independently
   per engine*, the read/write/admin capability each principal holds on each object — the UC
   side from the model's own privilege taxonomy, the Snowflake side from an object-aware
   classifier of the *translated* privileges. `test_snowflake_backend.py` asserts they are
   identical for the committed contract, and that the check has teeth (a mistranslation that
   drops or adds a capability is caught). This mirrors how `test_opa_consistency.py` runs two
   engines over one context and asserts equal verdicts — the same "trust through independent
   agreement" discipline, extended from *dual-engine* to *dual-platform*.

4. **The gate stays shared.** `policy_analyzer.py` and the OPA policy run once over the
   vendor-neutral model, so they already cover Snowflake; a new CI step
   (`snowflake_backend.py --check`) gates any cross-backend divergence.

## Consequences

**Benefits**
- The engine-agnostic claim is now *demonstrated*, not asserted: one JSON, two backends,
  provably equal least-privilege — the platform's strongest differentiator.
- Enforcement is offline-validatable end to end (`terraform validate` credential-free +
  Python consistency), preserving the project's credential-free-CI signature.
- Adds real Snowflake governance depth: functional-role RBAC, tag-based masking from
  classification, row-access scaffolding, and cost governance via resource monitors.

**Trade-offs**
- The two vocabularies are not isomorphic. Equivalence is defined at the **capability** level
  (read/write/admin), not privilege-identity — the honest invariant, since Snowflake collapses
  distinctions UC keeps (e.g. `BROWSE` vs `READ_FILES` both become stage `USAGE`). An
  *over-grant* (Snowflake conferring more than the UC intent) is reported as least-privilege
  drift rather than hidden.
- FEDERATED catalogs (Lakehouse Federation) have no faithful single-resource Snowflake
  equivalent and are out of scope for the Snowflake backend (filtered like the UC MANAGED/
  FEDERATED split).
- Column-level masking is applied via a governance tag on classified schemas; it takes full
  effect as tables/columns are onboarded and inherit the tag.
- The Snowflake storage integration **is** owned by this layer, mirroring how `dbx_creds`
  owns `databricks_storage_credential` for Unity Catalog. Both engines then read the same S3
  prefixes with no credential stored in either. The AWS↔Snowflake trust is two-way and would
  be circular; it is broken by deriving the IAM role's ARN as a string (account id + a chosen
  name), so the integration never waits on the role resource to exist.

**The one place the engines are not equivalent — and it is the engine's limit, not the map's**

A Snowflake *external* stage exposes exactly one privilege, `USAGE`, and it permits `COPY` in
**both** directions. Read-only and write-only external stages are therefore inexpressible: a
UC `READ_FILES` grant necessarily becomes read+write on Snowflake. No privilege mapping can
fix this — the only place the write boundary can be drawn is the storage integration's IAM
policy, which is per-integration, not per-role.

Rather than let this hide inside a capability-equivalence claim that would then be false,
`scripts/snowflake_backend.py` classifies it as a third issue kind, `engine_limitation`,
enumerated in `ENGINE_LIMITATIONS` with its rationale. It is **reported on every run**, and a
test asserts it can only ever cover an *added* capability on an external location — never a
lost one, and never anywhere else. A genuine mistranslation can therefore never be filed
under it.

The corollary is worth stating plainly: on Snowflake, `analysts` and `business_users` can
write to `loc_sales_gold`, and Unity Catalog does not permit that. That is a real,
surfaced least-privilege drift — precisely the kind of finding this platform exists to make
visible, rather than discover in an audit.
