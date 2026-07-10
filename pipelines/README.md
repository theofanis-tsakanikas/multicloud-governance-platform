# Data pipelines — governance over data *in motion*

This is **Level B** of the data story: data that actually flows through the
governed catalogs, used to *demonstrate* the platform's governance posture rather
than to do analytics. It stays faithful to the repo's discipline — **offline,
deterministic, zero new runtime dependencies** (stdlib `sqlite3`), and
reproducible from committed inputs.

> The thesis is *provable governance*. So the data exists to prove things:
> classification holds on real columns, PII is minimised out of gold, and one
> KPI table spans all three clouds. It is not a BI showcase.

## The flow

```
governance_model (the SAME model the analyzer governs)
        │
        ▼
generate_data.py     →  pipelines/data/raw/<cloud>/<catalog>.<schema>.csv
   deterministic synthetic data; PII-classed schemas get real PII-shaped columns
        │
        ▼
medallion.py         →  pipelines/data/warehouse.db  (+ gold CSVs)
   bronze (raw) → silver (clean, carries PII) → gold (aggregated, PII-minimised)
   + gold__global_kpis: AWS + Azure + GCP in one table (the Delta Sharing story)
        │
        ▼
profile_data.py      →  docs/governance/data_profile.json
   observed PII vs declared classification (drift), and "is gold PII-minimised?"
        │
        ▼
governance_dashboard.py  →  docs/governance/dashboard/index.html  (Level A)
```

## Why each step is on-thesis

| Step | Governance claim it turns into a checked fact |
|---|---|
| `generate_data.py` | Data shape is **derived from the governance model**, not invented — a `pii` schema gets real PII columns. |
| `medallion.py` (silver→gold) | **PII-minimisation**: the `pii`-classified source schemas carry email/phone/IP, and gold projects them away. |
| `medallion.py` (`global_kpis`) | **One plane across clouds**: GCP marketing gold joins AWS sales gold — Delta Sharing, executed (see [ADR-0009](../docs/adr/0009-cross-cloud-delta-sharing.md)). |
| `profile_data.py` | **Declared vs observed**: detects PII in the actual data and reconciles it against the declared `classification` — catching drift a declaration-only model can't. |

## Run it

```bash
make data        # generate → medallion → profile  (writes docs/governance/data_profile.json)
make dashboard   # render the static governance dashboard from all the artifacts
make demo-data   # the above, end-to-end, with output
```

The bulk data (`pipelines/data/`) is git-ignored and regenerated on demand;
only the small, deterministic `data_profile.json` and the dashboard are committed,
and CI asserts they are in sync (`--check`).

## On the live platform (the one-time recording)

Offline this runs in sqlite for a zero-dependency, reproducible demo. On the real
platform the identical transformations run as **Spark SQL on Databricks** across
the three clouds, feeding an **AI/BI dashboard** + a results notebook, with a
**Snowflake masking demo** alongside. The live-run bundle:

One-click via a **Databricks Asset Bundle** ([`databricks/databricks.yml`](databricks/databricks.yml)
+ [`bundle.sh`](databricks/bundle.sh)): `bundle deploy` uploads the SQL + notebook and
creates the Jobs; then you click **Run** (or `./bundle.sh run aws`). Two workspaces
(separate Databricks accounts), so two jobs:

On the live platform the PII boundary is drawn one step earlier than it is offline,
and more strongly: **the PII never enters the lakehouse at all**. `sales_aws.bronze`
is a federated read of `sales_rds_fed.orders` (no identities); silver joins
`sales_rds_fed.crm` only for `segment` and signup cohort. To reach an identity you
query the FOREIGN catalog directly, where `crm` is `pii` and granted to
`crm_managers` alone. Declared classification and observed data therefore agree —
declare `sales_aws.silver` as `pii` and the analyzer gate fails, as it should.

**All three** bronze layers are federated reads now. Nothing is synthesised inside
Databricks:

| bronze | reads | through |
|---|---|---|
| `sales_aws.bronze.sales_raw` | Postgres `orders.orders` | `sales_rds_fed` |
| `supplies_azure.bronze.supply_raw` | Azure SQL `orders` ⋈ `inventory` | `supply_sql_master` |
| `marketing_gcp.intelligence.web_raw` | BigQuery `analytics.sessions` | `marketing_bq_fed` |

Each source also holds a schema the medallion **never opens**: `crm` (Postgres) and
`web` (BigQuery) are classified `pii` and stay where they are.

The source systems seed themselves ([`sources/`](sources/), ADR-0014); the platform
never runs DDL against them. Seeding happens in the **pipeline run**, gated by
`seed_sources` — not in the deploy, because the deploy does not need rows:
`warm_foreign_catalog` asks for `SHOW SCHEMAS`, and the Azure stack deployed green
with its schemas empty. A real deployment sets `seed_sources: false` and the
application teams' data is already there.

| Path | Role |
|---|---|
| `sources/rds/seed.sql` | simulated OLTP source (AWS) — 800 customers (PII) + 6 040 orders |
| `sources/azure_sql/seed.sql` | simulated ERP (Azure) — 24 stock rows + 4 040 purchase orders |
| `sources/bigquery/seed.sql` | simulated analytics warehouse (GCP) — 20 000 sessions + 4 000 visitors (PII) |
| `databricks/aws/01_seed.sql`, `02_medallion.sql`, `03_executive.sql` | federated ingest → medallion → **executive cross-cloud view** (sales + supply + Delta-shared marketing) |
| `databricks/aws/04_dashboard_queries.sql` | tiles for the Databricks **AI/BI dashboard** |
| `databricks/aws/results_notebook.py` | presentation notebook — **only queries the gold tables** (the recording), with inline charts |
| `databricks/gcp/01_seed.sql`, `02_medallion.sql` | marketing bronze→silver→gold (then Delta-shared to AWS) |
| [`snowflake/read_gold_zone.sql`](snowflake/read_gold_zone.sql) | **zero-copy**: Snowflake reads the Parquet gold Databricks wrote to S3 |
| [`snowflake/masking_demo.sql`](snowflake/masking_demo.sql) | analyst-vs-admin PII masking, live on Snowflake (in an explicitly ungoverned `demo` schema) |

### Snowflake: a second engine, not a second copy

`03_executive.sql` writes the executive table once more as Parquet into the
`loc_sales_gold` external location. That is the same S3 prefix the Snowflake
storage integration already has access to, so
[`snowflake/read_gold_zone.sql`](snowflake/read_gold_zone.sql) queries those files
**in place** through an external table. Nothing is ingested into Snowflake; there
is no second copy to drift, and both engines enforce grants generated from the one
`sales_grants.json`. `scripts/snowflake_backend.py --check` proves the two
translations are access-equivalent, and reports the one distinction Snowflake
cannot express (ADR-0011).

Deploy+run from CI too: [`.github/workflows/dbx-pipeline.yml`](../.github/workflows/dbx-pipeline.yml).
The full deploy → seed → run → present → **teardown** storyboard is in
[`docs/LIVE_RUN_RUNBOOK.md`](../docs/LIVE_RUN_RUNBOOK.md). Like `genie_space.py --deploy`,
execution against a live workspace is deliberately deferred; the offline pipeline proves
the logic, these run it for real during the one-time recording.
