# Multi-Cloud Governance Platform

![Multi-Cloud Governance Platform — one contract, three clouds, two engines, zero public endpoints](./images/banner_new.png)

[![Config Validation](https://github.com/theofanis-tsakanikas/multicloud-governance-platform/actions/workflows/dbx-config-validate.yml/badge.svg)](https://github.com/theofanis-tsakanikas/multicloud-governance-platform/actions/workflows/dbx-config-validate.yml)
[![CI](https://github.com/theofanis-tsakanikas/multicloud-governance-platform/actions/workflows/dbx-validate.yml/badge.svg)](https://github.com/theofanis-tsakanikas/multicloud-governance-platform/actions/workflows/dbx-validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-1.9.x-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-%E2%89%A50.75-4CADE3)](https://terragrunt.gruntwork.io/)
[![Databricks](https://img.shields.io/badge/Databricks-Unity%20Catalog-FF3621?logo=databricks&logoColor=white)](https://www.databricks.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-zero--copy-29B5E8?logo=snowflake&logoColor=white)](#-snowflake--the-same-contract-a-second-engine)

**Data governance written once, in JSON, and enforced everywhere — across three clouds and two query
engines — by a gate that fails the pull request before a single resource exists.**

---

## Contents

| | |
|---|---|
| **[The gate](#governance-is-a-gate-not-a-report)** | A PR that leaks PII fails the check before merge. It runs offline, in under a second |
| **[The architecture](#the-architecture)** | One JSON contract → three clouds → two engines |
| **[What it looks like when it runs](#what-it-looks-like-when-it-runs)** | The catalogs, the lineage, the medallion, the dashboard — screenshots |
| **[The PII claim](#the-pii-claim-and-why-it-holds)** | Identities never leave Postgres, and the check returns zero rows |
| **[Private connectivity](#private-connectivity--three-clouds-no-public-path)** | Three transit hubs, zero public endpoints, proved at the packet level |
| **[❄️ Snowflake](#-snowflake--the-same-contract-a-second-engine)** | The same contract, a second engine — reading the same bytes, zero copies |
| **[✨ Genie](#-genie--the-governance-copilot)** | It reasons, writes SQL, charts, cites — and declines what it may not know |
| **[Run it](#run-it)** · **[Limits](#what-this-does-not-do)** · **[Decisions](#decisions)** | |

---

## Governance is a gate, not a report

Most "governance" is a report. Somebody runs a scan, a dashboard turns amber, a ticket gets filed,
and the grant that exposed a schema of customer emails has been live for three weeks.

Here it is a **gate**. A pull request that grants a group `SELECT` on a schema classified `pii`
fails the check and turns red *before* review — not merged first and flagged later. Make that check
**required** in branch protection and the red becomes a wall: **it does not merge.**

```
$ python scripts/policy_analyzer.py
[HIGH]  PII_BROAD_READ   schema:sales_rds_fed.crm → analysts
        PII is readable by a non-admin principal

policy scan: 1 high, 6 medium, 0 low, 2 info, 2 accepted
RESULT: FAIL                                                    ← exit 1, the PR is red
```

It runs with **no cloud and no credentials** — on a laptop, in a CI job that holds no secrets at all.
It cannot be sidestepped by not deploying, because it runs *before* deploying is a thing that could
happen.

And it is not a wall. It is a **ledger**:

```jsonc
// environments/dev/policy_exceptions.json
{
  "rule":          "PII_BROAD_READ",
  "object":        "schema:sales_rds_fed.crm",
  "principal":     "crm_managers",
  "justification": "CRM operations require read access to service accounts. Read-only (SELECT),
                    scoped to crm_managers, covered by DPIA-2026-014.",
  "approved_by":   "data-protection-officer",
  "expires":       "2026-12-31"        // ← and on 2027-01-01, CI goes red again
}
```

An expired exception stops suppressing its finding and the build fails. That is not a bug. **Nobody
gets to grant themselves access to PII and quietly forget about it.**

> ### Governance isn't "no". It's *"not without a reason — and not forever."*

**Nine rules**, four of them gating. On the committed configuration the scan reads
`0 high · 6 medium · 0 low · 2 info · 2 accepted` — and the two accepted are the two above.

---

## The architecture

![One contract. Three clouds. Two engines.](./images/prompts/prompt10.png)

One JSON document per domain declares its storage, its catalogs, its schemas, its grants, and the
**classification** of everything in it. Terragrunt reads that JSON natively — `jsondecode(file(...))`,
no code generation, no Python on the apply path
([ADR-0006](docs/adr/0006-zero-python-domain-governance.md)) — and turns it into Unity Catalog objects
across three clouds, and into Snowflake grants alongside them.

**What is actually declared** — read out of the repo, not from memory:

| | |
|---|---|
| Clouds · domains | **3** (AWS · Azure · GCP) · **3** (`sales`, `supply_chain`, `marketing`) |
| Contract files | **6** — one `*_infra.json` + one `*_grants.json` per domain |
| Securables | **30** — 7 external locations, 6 catalogs, 13 schemas, 4 volumes |
| Grants | **70**, across **8** groups |
| PII schemas | **2** — `sales_rds_fed.crm`, `marketing_bq_fed.web`. *(Azure holds none.)* |
| Terraform modules | **87** · Workflows **11** · Decision records **15** |
| Tests | **135**, infra-free, gating every push |

---

## What it looks like when it runs

### Catalogs — managed, federated, and shared, side by side

![The AWS metastore: managed catalogs, foreign catalogs, and a share received from GCP](./images/aws/catalogs/aws_dbx_catalogs.png)

Everything above came out of the same JSON. In the tree:

- **`sales_aws`, `supplies_azure`** — **MANAGED**: Delta tables in each cloud's own storage, with
  `bronze` / `silver` / `gold` schemas and a landing-zone volume.
- **`sales_rds_fed`, `supply_sql_master`** — **FOREIGN**: live federated views onto RDS Postgres and
  Azure SQL. No copy. Query them and the query runs *in the source engine*.
- **`shared_gcp_delta_share`** — under **Shares received**: the GCP gold table, Delta-Shared across
  two Databricks accounts and two metastores.

*(`marketing_gcp` and `marketing_bq_fed` are the same story on the GCP side — they live in the GCP
metastore, which this screenshot does not show.)*

### The medallion, run

Three SQL tasks — seed → medallion → executive — on a serverless warehouse. One minute, end to end.

![The medallion job DAG, all green](./images/pipeline_runs/aws_run_pipeline.png)

### The lineage Unity Catalog traced by itself

This is the picture worth the most. Nobody drew it: Unity Catalog followed the SQL.

![Cross-cloud lineage, traced automatically](./images/aws/gold/lineage.png)

Read it left to right. **Postgres** (`sales_rds_fed.orders`, `sales_rds_fed.crm`) and **SQL Server**
(`supply_sql_master.orders`, `supply_sql_master.inventory`) enter as federated sources. They become
bronze, then silver, then gold. A **Delta-Shared** table arrives from the GCP metastore
(`shared_gcp_delta_share.intelligence.gold_marketing_by_market`). All three converge into
`executive_cross_cloud`, which is then exported as Parquet for a fourth engine to read.

Look closely at `customers`: it carries `full_name`, `email`, `phone`. Look at `sales_clean`
immediately downstream: it carries `segment` and `signup_year`. **The PII minimisation is visible in
the graph.**

### The rejects

The sources are seeded **deliberately dirty**, because a source that arrives clean makes the
cleansing stage theatre. Silver removes 220 of 6,040 bronze rows — and it *reports* what it removed,
rather than dropping them silently.

![The rejects table — what the quality gate refused](./images/aws/silver/silver_data_rejected.png)

| Source | Tables | Deliberate defects |
|---|---|---|
| **RDS Postgres** | `crm.customers` (**800**, PII) · `orders.orders` (**6,040**) | 120 null markets · 61 refunds · 40 replays · 28 orphaned customers |
| **Azure SQL** | `inventory.stock` (24) · `orders.purchase_orders` (**4,040**) | 80 null markets · 41 returns · 40 replays |
| **BigQuery** | `analytics.sessions` (**20,000**) · `web.visitors` (**4,000**, PII) | 400 null markets |

*(The `orphan_customer` rows are kept and relabelled `unknown`, not dropped — the table reports them
because a governance platform that hides its own exceptions is not one.)*

### The table three clouds agree on

![The executive cross-cloud table](./images/aws/gold/executive_cross_cloud.png)

AWS sales ⋈ Azure supply ⋈ GCP marketing — inner-joined on `market`, one row per market. Poland is
the story: highest marketing ROI, longest lead times, 100% of stock below the reorder point.
**`stockout_risk = HIGH`, and every euro of its revenue is at risk.**

### The dashboard

![The executive dashboard](./images/dashboards/dashboards_with_roi.png)

### Delta Sharing — GCP gold, read on AWS

The GCP medallion writes its gold table into the **GCP** metastore. The AWS workspace reads it as a
share, and the executive join treats it like any other table. Two Databricks accounts, two metastores,
one query.

![The Delta-Shared catalog, arriving from GCP](./images/delta_share/delta_share_catalog.png)

---

## The PII claim, and why it holds

`crm.customers` carries `full_name`, `email`, `phone`. The medallion joins it — **inside Postgres,
through Lakehouse Federation** — and projects exactly two columns out of it: `segment` and
`signup_year`.

The strings `email`, `phone` and `full_name` appear in **no `SELECT` list anywhere in the pipeline**.
Nothing PII-shaped is ever written to managed storage. So the check is not a promise; it is a query
you can run:

![Governance proof — the gold tables carry zero PII](./images/aws/querries/governance_proof.png)

> **No rows returned.**

The identities stay where they were born. To reach one, you must query the federated source directly —
and that requires the `crm_managers` grant, which required a signed, dated, expiring exception.

---

## Private connectivity — three clouds, no public path

Every cloud takes `skip | public | private`, **independently**. In public mode the `integration` layer
creates **zero resources** — an apply that finishes in seconds having built nothing is the correct
outcome, not a failure.

In private mode, the database loses its front door entirely.

![One workspace. Three clouds. No public path.](./images/prompts/prompt9.png)

| | |
|---|---|
| 🟠 **AWS · RDS Postgres** | `publicly_accessible = false` — **the instance has no public address at all** |
| 🔷 **Azure · Azure SQL** | `publicNetworkAccess = Disabled` — **the server refuses the internet** |
| 🔵 **GCP · BigQuery** | reached through Google's private API VIP `199.36.153.8/30`, across an IPsec tunnel |

Three NCC private-endpoint rules, all `ESTABLISHED`, on one workspace:

![Three NCC private endpoint rules, all ESTABLISHED](./images/private_connection/databricks/ncc_private_endpoint_rules.png)

<table>
<tr>
<td width="50%"><img src="./images/private_connection/aws/rds.png" alt="RDS: Publicly accessible = No"></td>
<td width="50%"><img src="./images/private_connection/azure/server_public_access_disabled.png" alt="Azure SQL: Public network access = Disabled"></td>
</tr>
</table>

### Why it needed a transit hub

Databricks serverless runs inside an **AWS** Databricks account, and an NCC private-endpoint rule can
only ever create an **AWS** endpoint. There is no way to ask it for a private endpoint into Azure SQL
or BigQuery. The feature does not exist.

So the problem moved to ground where it does.

![Why a transit hub](./images/prompts/prompt5.png)

```
Databricks serverless (AWS)
  └─ NCC rule → AWS PrivateLink → internal NLB → ECS Fargate proxy
       └─ IPsec VPN → Azure private endpoint  /  Google's private API VIP
```

The proxies are TCP passthroughs. They terminate nothing, hold no credential, and understand no
protocol — the TLS session is end-to-end between Databricks and the database, and the proxy carries
bytes it cannot read.

### Proof, at the packet level

Configuration says what was *intended*. This says what actually **moved**:

![CloudWatch — 131 data-carrying sessions from private address space](./images/private_connection/aws/cloudwatch.png)

`10.11.x` is the GCP transit hub; `10.10.x` is the Azure one. Both are private address space. A health
check carries **zero** bytes; these carry up to **1.9 MB**. 131 sessions, and not one of them touched
the internet. *(The evidence is preserved in [`docs/evidence/`](docs/evidence/private-connectivity.md) —
the log groups themselves expired a day later.)*

> **The honest footnote, and it matters:** BigQuery has **no "disable public access" switch**. It is a
> Google-managed API; there is nothing to turn off. What is private on that path is the **connection** —
> it travels through Google's private VIP and does not touch the internet. Removing BigQuery's public
> API surface altogether is VPC Service Controls, which this repo does not do.

*Per-cloud walkthroughs:* [AWS](images/prompts/prompt2.png) · [Azure](images/prompts/prompt6.png) ·
[GCP](images/prompts/prompt7.png) · [public vs private](images/prompts/prompt3.png)

---

---

# ❄️ Snowflake — the same contract, a second engine

Everything above this line is **Databricks**. Everything below it is **Snowflake**, governed by the
*same JSON*, reading the *same bytes* ([ADR-0011](docs/adr/0011-snowflake-enforcement-backend.md)).

### One gold file. Two engines. Zero copies.

![Zero-copy: one gold layer, two engines](./images/prompts/prompt4.png)

Databricks writes the gold layer once, as Parquet, into `s3://…/sales/gold-zone/executive/`.
Snowflake reads **that same object, in place**, through an external table over an external stage:

![Snowflake reading the same S3 object Databricks wrote](./images/snowflake/querry.png)

Same six markets. Same revenue. Same ROI. **A different engine, and not one byte copied.**
`SELECT metadata$filename` returns the identical S3 key — the proof is in the notebook, not in this
sentence.

The external location in Unity Catalog and the stage in Snowflake even **share a name** —
`loc_sales_gold` — and that is not a coincidence. Both are generated from the same contract.

### The governance travels with it

Because the contract drives Snowflake's grants too, the mechanisms exist on that side as well —
account roles, privilege grants, resource monitors, and **column masking**:

![Column-level masking in Snowflake](./images/snowflake/querry1.png)

`DEV_METASTORE_ADMINS` sees the email. `DEV_ANALYSTS` sees `***MASKED***`. Same query, same table,
different role.

*(That demo schema generates its own synthetic PII on purpose. The **governed** catalogs have nothing
to mask, **because the PII never left Postgres** — which is exactly the point, and why the demo has
to invent some.)*

---

# ✨ Genie — the governance copilot

A Genie space over **four read-only tables** generated from the domain JSON. It is the *convenience*
tier of the platform, and it is deliberately subordinate to the deterministic core:

```
policy_analyzer.py   →  decides what is safe        (the trust — it fails the PR)
governance_report.py →  documents it                (accountability, on demand)
genie_space.py       →  lets a human ask in English (read-only convenience)
```

**The analyzer decides. Genie only restates what the analyzer already proved.**

### The cage: four tables, and nothing else

![The Genie space's sources — four governance tables](./images/genie/sources.png)

`objects` · `access_matrix` · `pii_map` · `policy_findings`. That is the entire world it can see.
It holds no credential, reads no business data, and cannot grant anything.

### It reasons, executes, and cites

![Genie answering the PII question across three clouds](./images/genie/question1b.png)

Asked *"which datasets hold PII, and who can read them across all three clouds?"* it plans two
queries, runs them, and answers with a table and footnoted citations. Note the last line: **"Azure —
No PII datasets are currently cataloged."** It did not invent one to fill the gap.

### It writes the SQL, and it shows you

![The SQL Genie generated, revealed by Show code](./images/genie/question3e.png)

Every answer carries a **Show code** link. This is not a black box producing prose — it is SQL over
governed tables, and you can read it, run it, and check it yourself.

### It charts what it found

<table>
<tr>
<td width="50%"><img src="./images/genie/question3b.png" alt="Policy findings by cloud"></td>
<td width="50%"><img src="./images/genie/question3d.png" alt="Findings by rule type, and the accepted exceptions"></td>
</tr>
</table>

Findings by cloud, findings by rule — and the **accepted exceptions read straight out of the ledger**,
with their justifications and their DPIA references. The exception mechanism is not something the AI
was told about; it is a row in a table it can query.

### And it declines what it is not allowed to know

![Genie refusing a question outside its scope](./images/genie/question2.png)

> **Q:** *What is the CEO's home address?*
>
> **A:** *"I cannot provide that information. As the governance copilot, I have **read-only access to
> metadata** about data governance — such as which datasets exist, their classifications, access
> grants, and policy findings. I do not have access to the underlying business data itself."*

**That refusal is the feature.** It is not that the AI answers; it is that it *knows what it is not
allowed to know* — and the boundary is not a promise made in a prompt. Genie queries as the human
asking, so Unity Catalog's own grants are the ceiling on anything it can return.

It also needs **no cloud stack**: its tables are facts read out of the JSON, in a managed catalog on
the metastore root. The copilot survived a full teardown of AWS, Azure and GCP. It describes the
*governance*, not the infrastructure.

```bash
make genie-deploy      # idempotent; needs only the bootstrap workspace + a SQL warehouse
```

---

## Run it

```bash
# Offline — no cloud, no credentials. This is the governance layer, whole.
make validate-config    # schema + consistency + wiring
make policy-scan        # the gate: exit 1 on any unacknowledged HIGH
make opa                # the same rules, cross-checked in Rego
make governance-report  # regenerate docs/governance/ (CI asserts it stays in sync)
make demo               # all of the above, end to end
pytest -q               # 135 tests

# Cloud — through GitHub Actions, not the CLI.
#   DBX Bootstrap  → metastore, serverless workspace, SPN, KMS, NCC  (once per account)
#   DBX Deploy     → per-cloud: skip | public | private
#   DBX Pipeline   → seed the sources, run the medallion, publish the dashboard
#   DBX Genie      → provision the governance copilot (needs no cloud stack)
#   DBX Destroy    → reverse-order teardown; never touches bootstrap
```

Everything that touches a cloud runs in CI, with OIDC. **No long-lived keys**, and no secret is stored
in this repository — every credential is fetched at plan time by shelling out to the cloud's own CLI
([ADR-0002](docs/adr/0002-secrets-via-run-cmd-at-plan-time.md)).

### Layout

```
environments/dev/domains/                  ← THE CONTRACT. Everything else is a consequence.
environments/dev/policy_exceptions.json    ← documented, time-bound, expiring
scripts/                                   ← the gate + the report + the copilot (offline, stdlib)
policy/opa/                                ← the gating rules, re-implemented in Rego
schema/                                    ← JSON Schema for the contract (Draft 2020-12)
infra/{aws,azure,gcp,databricks,bootstrap,snowflake}/modules/    ← 87 modules
environments/{dev,prod}/                   ← Terragrunt wiring; prod is a file-for-file mirror
pipelines/                                 ← the medallion (Databricks SQL) + the simulated sources
docs/adr/                                  ← 15 decision records
docs/governance/                           ← GENERATED. CI fails if it drifts from the contract.
```

---

## What this does **not** do

A portfolio that only lists what works is a sales page. This is the rest of it.

- **`prod/` has never been applied.** It is a file-for-file mirror of `dev/`
  ([ADR-0010](docs/adr/0010-environments-as-file-mirrors.md)) and its `config.hcl` is a placeholder —
  `aws_account_id = "111111111111"`. The architecture supports promotion by config diff. Nobody has
  done it.
- **The OPA cross-check is not fully independent.** It re-implements **3 of the 4** gating rules
  (`PII_WRITE` is missing) and consumes the analyzer's own output as its input — so it re-derives the
  *logic* independently, not the *facts*.
- **The gate does not fail on MEDIUM.** Six `ALL_PRIVILEGES_NONADMIN` findings are open today and CI
  is green. `--strict` would fail them; CI does not pass `--strict`. A deliberate posture, stated
  rather than hidden.
- **Live drift detection is not wired up.** `catalog_drift.py --live` is implemented and unit-tested
  against synthetic data; it has never run against a real Unity Catalog in CI. A grant changed by hand
  in the UI will not be caught.
- **The offline `pipelines/` sqlite demo is a different pipeline.** It shares the *governance model*
  with the Databricks medallion — not the data model. Different tables, different columns, no dirty
  data. It exists so the governance story runs with no cloud at all.
- **The source systems are simulated**, and the boundary is explicit
  ([ADR-0014](docs/adr/0014-simulated-source-systems.md)). A real platform does not own its OLTP
  sources; pretending otherwise would be the lie that makes everything else suspect.
- **BigQuery's public API surface still exists.** See above.

---

## Cost

`scripts/cost_estimate.py` prices the whole platform — Databricks compute, Snowflake credits, and all
three clouds — into one figure and a carbon floor, **offline, before a single resource exists**:

```
~$2,646 / month   ·   ~79 kg CO₂e / month        →  docs/governance/COST.md
```

Every price is an illustrative placeholder, declared as such in
`environments/dev/cost_assumptions.json`. It is a floor for awareness, not a quote.

---

## Decisions

Fifteen ADRs in [`docs/adr/`](docs/adr/) record what was chosen and — more usefully — what was
rejected, and one records what building it proved **wrong**
([ADR-0008](docs/adr/0008-single-connectivity-toggle.md) said one connectivity toggle; there are
three).

| | |
|---|---|
| [0001](docs/adr/0001-terragrunt-over-custom-orchestrator.md) | Terragrunt instead of a hand-rolled Python orchestrator — the DAG is declared, not coded |
| [0006](docs/adr/0006-zero-python-domain-governance.md) | The domain contract is JSON that Terragrunt reads natively. No code generation |
| [0007](docs/adr/0007-deterministic-governance-bounded-llm.md) | The deterministic analyzer decides and gates. The LLM is bounded on top of it |
| [0011](docs/adr/0011-snowflake-enforcement-backend.md) | Snowflake as a second enforcement backend for the same contract |
| [0013](docs/adr/0013-stable-names-over-deployment-id-suffix.md) | Stable, meaningful resource names over a rotating suffix |
| [0014](docs/adr/0014-simulated-source-systems.md) | The OLTP sources are simulated, and the boundary is explicit |

---

## Security

Vulnerability reporting, scope, and the known limitations: [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE).
