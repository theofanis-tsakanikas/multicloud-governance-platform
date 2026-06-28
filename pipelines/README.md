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
| `medallion.py` (silver→gold) | **PII-minimisation**: email/phone/IP live in silver and are projected away at gold. |
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

## On the live platform (deferred)

Offline this runs in sqlite for a zero-dependency, reproducible demo. On the real
platform the identical transformations run as **Spark SQL on Databricks** across
the three clouds — see [`databricks/medallion_spark.sql`](databricks/medallion_spark.sql).
Like `genie_space.py --deploy` and `catalog_drift.py --live`, execution against a
live workspace is deliberately deferred; the artifacts are build-time, the cluster
is deploy-time.
