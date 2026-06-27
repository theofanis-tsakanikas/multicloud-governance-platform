# ADR-0009: Cross-cloud Delta Sharing in native HCL

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

The marketing domain lives on GCP, but its catalog volumes need to be consumable
from the AWS metastore (one governance plane, data physically on different clouds).
Databricks Delta Sharing supports this, but wiring a share across two clouds means
talking to two Databricks control planes and deciding *which* objects to share.

## Decision

Implement the share in `gcp/data_platform/dbx_delta_sharing` using **dual
Databricks provider aliases** (one per cloud) and build the share map natively in
HCL from `marketing_infra.json` — selecting only volumes explicitly flagged
`shared: true`.

```hcl
shared_schemas = distinct(flatten([
  for cat in local.infra.catalogs : [
    for s in lookup(cat, "schemas", []) : { catalog = cat.catalog_name, schema = s.schema_name }
    if anytrue([for v in lookup(s, "volumes", []) : lookup(v, "shared", false)])
  ] if cat.type == "MANAGED"
]))
```

## Consequences

- What is shared is data-driven (a flag in the domain JSON), consistent with
  [ADR-0006](0006-zero-python-domain-governance.md) — no separate share config.
- The cross-cloud relationship is expressed in the same IaC as everything else,
  with explicit provider aliases making the two control planes visible.
- The share layer depends on both clouds' bootstrap + governance outputs, so its
  place in the DAG is later than single-cloud layers (see the GCP dependency graph
  in ARCHITECTURE.md).

## Alternatives considered

- **Manual share setup in the UI** — rejected: not reproducible, not reviewable.
- **A separate share-definition file** — rejected: the domain JSON already
  describes the volumes; a `shared` flag keeps one source of truth.
