# Live-Run Runbook — the one-time cloud recording

The platform is **offline-first** (anyone runs `make demo` in ~30s). This runbook
is the **one-time live deployment** you stand up to record real screenshots/video
proving it runs on real infrastructure — then **tear down** to stop the cost.

> Audience of the recording: **executives**. Every step below maps to a beat in
> the storyboard (§4). Keep the narration business-first, plumbing second.

**Cost note:** ~€2.6k/month *floor* while live (see `docs/governance/COST.md`).
Stand up → record → **destroy the same day**.

---

## 1 · Prerequisites (once)
- Accounts: AWS, Azure, GCP, **Databricks** (AWS + GCP), **Snowflake**.
- The 4 GitHub secrets filled (`DBX_DEPLOY_ROLE_ARN`, `AZURE_*`) — see the
  credentials table you already have.
- Cloud-store secrets created (SPN, seed creds, RDS/SQL passwords, BQ key).
- `config.hcl` set to **your** account IDs / ARNs.
- Local tools: Terraform 1.9.x, Terragrunt ≥0.75, AWS CLI, `az`, `gcloud`,
  `snow` (Snowflake CLI) with a `~/.snowflake/config.toml` profile.

## 2 · Deploy the infrastructure (the containers + governance)
```bash
make bootstrap-aws          # Databricks metastore + serverless workspace (AWS home)
make bootstrap-gcp          # GCP metastore + workspace
make apply-aws              # catalogs / schemas / grants (sales) + connectors
make apply-azure            # supply-chain governance (hangs off AWS home)
make apply-gcp              # marketing governance + Delta Sharing (GCP → AWS)
make apply LAYER=aws/data_platform/snowflake_governance   # Snowflake roles/grants/masking
```
This creates the **containers and access rules** — not the data. (Terraform makes
`catalog`/`schema`/`volume`/`grants`, never tables.)

## 3 · Seed + run the data — one click, via Databricks Asset Bundle
No copy-paste. The [Asset Bundle](../pipelines/databricks/databricks.yml) uploads
the SQL + the results notebook into your workspace **and creates the Jobs**;
then you click **Run** (or `bundle.sh run`). The medallion runs `seed → medallion
→ executive` in order — that is the whole pipeline, one click.

```bash
cd pipelines/databricks
export DATABRICKS_AWS_HOST=https://<aws-workspace>   DATABRICKS_GCP_HOST=https://<gcp-workspace>
export WAREHOUSE_ID=<your-sql-warehouse-id>

./bundle.sh deploy gcp && ./bundle.sh run gcp     # marketing → gold (then Delta-shared)
./bundle.sh deploy aws && ./bundle.sh run aws     # sales+supply → gold → executive view
```
After deploy, the **`results_notebook`** and **`04_dashboard_queries`** are in your
workspace ready to open. Or run the whole thing from CI:
[`dbx-pipeline.yml`](../.github/workflows/dbx-pipeline.yml) (`Actions → run`).

Then, in the UI:
- **AI/BI Dashboard:** SQL Editor → paste each query from `aws/04_dashboard_queries.sql` → add as a visualization.
- **Snowflake masking demo:** run [`pipelines/snowflake/masking_demo.sql`](../pipelines/snowflake/masking_demo.sql) in a worksheet.

> **Delta Sharing note:** `aws/03_executive.sql` references marketing gold as
> `shared_gcp_delta_share.intelligence.gold_marketing_by_market` — the GCP table shared
> to AWS by the `dbx_delta_sharing` layer. For a single-workspace dry run, point
> it at the local `marketing_gcp.intelligence.gold_marketing_by_region` instead.

## 4 · Recording storyboard (the CEO cut)
1. **The gate blocks a bad PR** *(30s)* — add a grant that leaks PII, push, show CI
   go red. *"Nothing unsafe reaches production."*
2. **`terraform apply`** *(fast-forward)* — catalogs & grants come alive across 3 clouds.
3. **One-click pipeline** — `./bundle.sh run gcp` then `run aws` (or the CI button): the
   whole medallion runs and the gold tables appear. *"One click builds the whole flow."*
4. **Show the results** — open `results_notebook.py` and click through; each query on the
   **gold** tables renders a chart. Then **Delta Sharing**: the GCP marketing table
   queried **on AWS** (no copy).
5. **The Executive AI/BI Dashboard** — the cross-cloud insight. *The "wow": demand
   (GCP) → revenue (AWS) → supply risk (Azure), per region, in one view.*
6. **Governance proof** — show gold has **zero** PII columns; then the **Snowflake
   masking demo**: analyst sees `***MASKED***`, admin sees the email. *"One contract,
   two engines."*
7. **Teardown** — *"and I delete it all, because the infrastructure is code."*

## 5 · Tear down (stop the cost)
```bash
make destroy-gcp
make destroy-azure
make destroy-aws
make bootstrap-gcp-destroy
make bootstrap-aws-destroy
# Snowflake: DROP DATABASE sales;  (+ roles/warehouse if desired)
```
Resource names are **stable** (no `deployment_id`) — a re-deploy just works. Only a
just-destroyed Databricks object still in a soft-deleted state can cause a transient name
clash; wait for it to purge (or purge it via the Databricks API) and re-apply.

---

### Files in this bundle
- [`pipelines/databricks/databricks.yml`](../pipelines/databricks/databricks.yml) + [`bundle.sh`](../pipelines/databricks/bundle.sh) — the Asset Bundle (one-click)
- `pipelines/databricks/aws/` — `01_seed.sql`, `02_medallion.sql`, `03_executive.sql`, `04_dashboard_queries.sql`, `results_notebook.py`
- `pipelines/databricks/gcp/` — `01_seed.sql`, `02_medallion.sql`
- [`pipelines/snowflake/masking_demo.sql`](../pipelines/snowflake/masking_demo.sql)
- [`.github/workflows/dbx-pipeline.yml`](../.github/workflows/dbx-pipeline.yml) — optional CI deploy+run

> These are the **live-run artifacts**. They are written for the live workspaces
> and are not exercised by the offline CI (which stays credential-free). Run and
> fine-tune them in your workspace during the rehearsal before recording.
