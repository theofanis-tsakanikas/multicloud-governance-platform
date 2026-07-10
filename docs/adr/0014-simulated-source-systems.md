# ADR-0014: The OLTP source systems are simulated, and that boundary is explicit

- **Status:** Accepted
- **Date:** 2026-07-10
- **Relates to:** [ADR-0011](0011-snowflake-enforcement-backend.md) (engine-agnostic governance)

## Context

Lakehouse Federation is the reason this platform exists: governing data **in
place**, in a live operational database, with the same classification and RBAC
model used for data that has landed in object storage. To demonstrate that, the
platform needs a remote engine to federate against — a Postgres database on AWS,
a SQL Server on Azure, a BigQuery project on GCP.

Those engines do not belong to a governance platform. In any real organisation
they are owned by an application team: the `crm` schema is created and evolved by
whatever writes to it (a Flyway migration, a Django `makemigrations`, a Liquibase
changelog), on that team's release cadence, in that team's repository. A
governance platform **consumes** a source system; it does not author it.

But a portfolio deployment must run end-to-end from an empty cloud account. There
is no application team to wait for, and no pre-existing database to point at.

This creates a tension between two properties that are both worth having:

1. **Self-contained** — `make bootstrap && make apply-aws` works on a fresh
   account, and the federated catalog resolves real schemas from a real engine.
2. **Production-honest** — the code does not imply that a governance platform
   provisions and migrates the operational databases of other teams.

## Decision

Provision the source systems, but **fence them off and name them as simulations**
rather than hiding the seam.

Concretely, two layers per cloud are marked as *simulated source system* and are
**not** part of the governance platform proper:

| Cloud | Simulated source-system layers |
|---|---|
| AWS | `storage/rds` (the `sales-db-instance` Postgres), `storage/rds_schemas` (`crm`, `orders`) |
| Azure | `storage/mssql`, `storage/mssql_schemas` |
| GCP | `storage/bigquery` (the `analytics` and `web` datasets) |

Everything downstream of them — the `databricks_connection`, the FOREIGN catalog,
the schema grants, the classification model, the policy analyzer — is platform
code and is unaware that the engine was provisioned by us.

The distinction is drawn along a defensible line: **provisioning the engine vs.
authoring its schema.**

- Provisioning an RDS instance with Terraform is ordinary platform work. Many
  real platform teams do exactly this.
- Creating the `crm` and `orders` schemas *inside* it is **not**. That is the
  application's data model, and it is the part of this repo that would not exist
  in production.

`rds_schemas` / `mssql_schemas` / `storage/bigquery` exist solely so the federated
catalog has something to discover.

**When the data arrives, and why it is not at apply time.** The seed scripts live
in `pipelines/sources/` and run as the first steps of the *pipeline*, behind a
`seed_sources` switch that a real deployment sets to `false`. They are not part of
the deploy, and not because it would be untidy: the deploy does not need them.
`warm_foreign_catalog` asks the foreign catalog for `SHOW SCHEMAS`, not for rows —
the Azure stack deployed green with `inventory` and `orders` completely empty. Data
belongs to the run; schemas belong to the infrastructure. Putting an `INSERT` in a
governance platform's `apply` would erase the very boundary this record draws.

## Consequences

**What changes in production**

Delete the simulated layers and point the connector at the application team's
existing endpoint. The `dbx_*_connector` layers already take `host`, `port`,
`user`, and `password` as inputs resolved from config and Secrets Manager — so
the change is a hostname and a credential, not a refactor. **No module under
`infra/databricks/` changes at all.** That the swap is this cheap is the point:
it is evidence the governance layer is genuinely decoupled from the engine, which
is the same claim [ADR-0011](0011-snowflake-enforcement-backend.md) makes about
Snowflake.

**What this costs**

- The apply graph carries two layers per cloud that a real deployment would not
  have, and the deploy takes longer for it (an RDS instance is ~5 minutes).
- The remote engine must be **running** at apply time, because the FOREIGN
  catalog's schemas are discovered from it (see `CLAUDE.md` gotcha #3). A stopped
  `sales-db-instance` fails the deploy. In production that is a property of the
  source system's own availability, not of this repo.

**What this buys**

- A reviewer can clone the repo, run one command, and watch a query cross from
  Unity Catalog into a live Postgres with PII grants enforced — without being
  handed a database first.

## Alternatives considered

- **Point at a pre-existing database via `data` sources / variables only.**
  The production-correct shape, and the one this repo degrades to. Rejected as
  the *default* because it makes the repo undemonstrable without external setup —
  the federation, which is the centrepiece, could not be shown running.

- **Keep provisioning the engines but say nothing.** Rejected. A reader who knows
  the domain will notice that a governance platform is running DDL against an
  OLTP database and will read it as a misunderstanding of ownership boundaries.
  The seam is not a flaw to hide; where a demo's simulation ends is exactly the
  kind of thing an architecture record exists to state.

- **Seed the schemas with a `local-exec` script outside Terraform.** Same
  simulation, but now with drift between what Terraform knows and what exists,
  and no state to destroy cleanly. Rejected: it hides the seam *and* is worse
  engineering.
