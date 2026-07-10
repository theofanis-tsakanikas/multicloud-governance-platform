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

The source system seeds itself ([`sources/rds/seed.sql`](sources/rds/seed.sql),
ADR-0014); the platform never runs DDL against it.

| Path | Role |
|---|---|
| `sources/rds/seed.sql` | the **simulated OLTP source** — 800 customers (PII) + 6 000 orders, deterministic |
| `databricks/aws/01_seed.sql`, `02_medallion.sql`, `03_executive.sql` | federated ingest → medallion → **executive cross-cloud view** (sales + supply + Delta-shared marketing) |
| `databricks/aws/04_dashboard_queries.sql` | tiles for the Databricks **AI/BI dashboard** |
| `databricks/aws/results_notebook.py` | presentation notebook — **only queries the gold tables** (the recording), with inline charts |
| `databricks/gcp/01_seed.sql`, `02_medallion.sql` | marketing bronze→silver→gold (then Delta-shared to AWS) |
| [`snowflake/masking_demo.sql`](snowflake/masking_demo.sql) | analyst-vs-admin PII masking, live on Snowflake |

Deploy+run from CI too: [`.github/workflows/dbx-pipeline.yml`](../.github/workflows/dbx-pipeline.yml).
The full deploy → seed → run → present → **teardown** storyboard is in
[`docs/LIVE_RUN_RUNBOOK.md`](../docs/LIVE_RUN_RUNBOOK.md). Like `genie_space.py --deploy`,
execution against a live workspace is deliberately deferred; the offline pipeline proves
the logic, these run it for real during the one-time recording.
