# CLAUDE.md — Multi-Cloud Governance Platform

Terraform (via Terragrunt) provisioning for a Databricks Unity Catalog platform deployed across AWS, Azure, and GCP from a single `environments/dev/` configuration tree. It manages cloud infrastructure (VPCs, storage, databases), Databricks workspaces, and data governance (catalogs, schemas, external locations, grants) as code.

Full architecture detail and dependency graphs are in [ARCHITECTURE.md](ARCHITECTURE.md). This file covers operational knowledge that isn't derivable from reading the code.

---

## Repo layout

```
.
├── terragrunt.hcl              # Root: S3 remote state + DynamoDB lock (inherited by all children)
├── Makefile                    # validate / plan / apply / destroy + policy-scan / governance-report (ENV=dev|prod)
├── environments/
│   ├── dev/                    # dev environment (config.hcl, domains, bootstrap, per-cloud stacks)
│   │   ├── config.hcl          # Single source of truth for every config value
│   │   ├── policy_exceptions.json  # Documented, time-bound deviations for the access-policy analyzer
│   │   └── domains/{aws,azure,gcp}/  # Domain JSON (infra + grants per domain; schemas carry classification/PII)
│   └── prod/                   # prod environment — file-for-file mirror of dev (own config.hcl)
├── scripts/                    # Offline governance copilot (no cloud, no creds, CI-gated):
│   ├── validate_domains.py     #   domain-config schema/consistency/wiring validator (+ optional JSON Schema)
│   ├── governance_model.py     #   shared parser: domain JSON → objects + grants + classification
│   ├── policy_analyzer.py      #   deterministic least-privilege / PII gate (HIGH-gating); --format sarif, --warn-expiring
│   ├── governance_report.py    #   generates docs/governance/REPORT.md + grounding pack
│   ├── governance_metrics.py   #   trendable telemetry → docs/governance/metrics.json (CI --check)
│   ├── cost_estimate.py        #   multi-cloud + Databricks cost & carbon floor → docs/governance/COST.md (CI --check)
│   ├── catalog_drift.py        #   reconcile declared grants vs live Unity Catalog (deferred --live)
│   └── genie_space.py          #   Genie governance-space SQL + grounding-contract instructions (deferred deploy)
├── pipelines/                  # Level B — governance over data in motion (offline, stdlib sqlite3):
│   ├── generate_data.py        #   deterministic synthetic data shaped by the governance model
│   ├── medallion.py            #   bronze→silver→gold + cross-cloud KPI table (PII-minimised gold)
│   ├── profile_data.py         #   observed PII vs declared classification → docs/governance/data_profile.json
│   └── databricks/             #   the same medallion as Spark SQL for the live platform (deferred)
├── schema/                     # Versioned JSON Schema (Draft 2020-12) for domain config + IDE autocomplete
├── policy/opa/                 # Independent OPA/Rego re-implementation of the gating rules (CI cross-check)
├── docs/adr/                   # Architecture Decision Records (the decision ledger)
├── docs/governance/            # Generated: REPORT.md + governance_context.json + metrics.json + COST.md + data_profile.json + dashboard/ + genie/
└── infra/
    ├── aws/modules/            # Pure Terraform modules — no provider.tf, no backend.tf
    ├── azure/modules/
    ├── gcp/modules/
    ├── databricks/modules/     # Cloud-neutral Databricks resources (catalog, external_location)
    └── bootstrap/modules/      # Bootstrap-specific modules (metastore, workspace, identities)
```

Modules under `infra/` contain only `resource`, `variable`, and `output` blocks. Provider and backend configurations are generated at plan time by Terragrunt's `generate "providers"` blocks in each `environments/dev/*/terragrunt.hcl`.

---

## Dependency layers and apply order

### How Terragrunt enforces order automatically

Every `terragrunt.hcl` that needs an output from another layer declares a `dependency {}` block:

```hcl
dependency "foundation" {
  config_path = "../../foundation"
}
```

Terragrunt reads all `dependency {}` blocks across the working directory tree and builds a DAG. `terragrunt run-all apply` executes layers in topological order — no manual sequencing needed.

When you run `make apply LAYER=aws/security/iam` (single-layer mode), Terragrunt does **not** apply dependencies automatically. It reads their outputs from S3 remote state. Those layers must already be applied.

### Intended apply sequence

**Bootstrap (once per account — must come before everything else):**
```
make bootstrap-aws    # required for all three clouds
make bootstrap-gcp    # required for GCP only
```

**Per-cloud stacks (Terragrunt resolves order within each):**
```
make apply-aws        # foundation → security → network → storage → integration → data_platform
make apply-azure      # foundation → security → network → storage → integration → data_platform
make apply-gcp        # foundation → security → network → storage → integration → data_platform
```

See [ARCHITECTURE.md](ARCHITECTURE.md#dependency-graphs) for the full Mermaid graphs showing every `dependency {}` edge.

---

## Secrets flow

All secrets are fetched at plan/apply time via `run_cmd`. Nothing is stored in code or passed as environment variables.

**Pattern (from `aws/data_platform/dbx_governance/terragrunt.hcl`):**
```hcl
locals {
  spn = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}
```

At `terragrunt plan`, `run_cmd` shells out to the AWS CLI. The runner needs AWS credentials with Secrets Manager read access. In CI this comes from OIDC (`DBX_DEPLOY_ROLE_ARN`). Locally it comes from the active AWS profile.

**What is stored where:**

| Secret | Store | Path / ID in `config.hcl` |
|---|---|---|
| Databricks SPN (client_id + secret) | AWS Secrets Manager | `spn_secret_id = "databricks/spn"` |
| AWS bootstrap seed credentials | AWS Secrets Manager | `seed_credentials_id` |
| Azure bootstrap seed credentials | AWS Secrets Manager | `azure_seed_secret_arn` |
| GCP bootstrap seed credentials | AWS Secrets Manager | `gcp_seed_secret_arn` |
| RDS password | AWS Secrets Manager | `password_name = "sales/rds-secret"` |
| SQL Server password | Azure Key Vault | fetched via `az keyvault secret show` |
| BigQuery service account key | GCP Secret Manager | fetched via `gcloud secrets versions access` |

**Important:** Azure and GCP seed credentials live in **AWS** Secrets Manager, not in their own secret stores. This is intentional — the bootstrap sequence authenticates to Azure/GCP before their secret stores are available. It means AWS credentials are required even when running Azure-only or GCP-only layers that use seed credentials.

---

## Domain governance flow

Domain governance is defined in JSON, loaded natively by Terragrunt, and passed to Terraform as JSON-encoded strings. No Python, no code generation, no intermediate files.

**End-to-end flow:**

1. Edit `environments/dev/domains/<cloud>/<domain>_infra.json` (storage layout) and/or `<domain>_grants.json` (RBAC).

2. In the relevant `data_platform/dbx_governance/terragrunt.hcl`, Terragrunt reads and transforms the files at plan time:
   ```hcl
   infra    = jsondecode(file("${get_terragrunt_dir()}/../../domains/aws/sales_infra.json"))
   grants   = jsondecode(file("${get_terragrunt_dir()}/../../domains/aws/sales_grants.json"))
   managed  = [for c in local.infra.catalogs : c if c.type == "MANAGED"]
   ```

3. Terragrunt passes the filtered values to Terraform as `jsonencode()` inputs:
   ```hcl
   inputs = {
     catalogs_json              = jsonencode(local.managed_catalogs)
     managed_schema_grants_json = jsonencode(local.managed_schema_grants)
     ...
   }
   ```

4. Terraform iterates with `for_each` to create catalogs, schemas, external locations, and grants.

**JSON schema summary:**

`*_infra.json` — defines storage layout: external location paths, catalog type (`MANAGED` vs `FEDERATED`), schemas, volumes.

`*_grants.json` — defines Databricks RBAC: which group (`data_engineers`, `analysts`, etc.) gets which privilege on which object (external location, catalog, schema, volume).

**Adding a new domain:** Follow the README steps. The key step that is easy to miss: update the `domain_path` locals in the relevant `dbx_governance/terragrunt.hcl` to point at the new JSON files.

---

## GitHub Actions workflows

All six workflows live in `.github/workflows/`. The `bootstrap`, `deploy`, and `destroy` workflows target the `dev` GitHub Environment (configure manual approval gates there if needed).

| Workflow | File | Trigger | Required secrets |
|---|---|---|---|
| Validate | `dbx-validate.yml` | PR touching `infra/**`, `environments/**`, `terragrunt.hcl`, `dbx-validate.yml` | `DBX_DEPLOY_ROLE_ARN` |
| Config validate | `dbx-config-validate.yml` | PR touching domains/scripts/docs/governance — **no cloud creds**: runs `validate_domains` + the `policy_analyzer` gate + report/Genie `--check` + pytest | — |
| Drift detection | `dbx-drift.yml` | Weekly schedule (+ manual) — `terragrunt run-all plan -detailed-exitcode` per cloud; opens/updates a `drift`-labelled issue | `DBX_DEPLOY_ROLE_ARN` |
| Bootstrap | `dbx-bootstrap.yml` | Manual (`workflow_dispatch`) | `DBX_DEPLOY_ROLE_ARN` |
| Deploy | `dbx-deploy.yml` | Manual (`workflow_dispatch`) | `DBX_DEPLOY_ROLE_ARN`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| Destroy | `dbx-destroy.yml` | Manual — requires typing `DESTROY` to confirm | Same as Deploy |

**Validate** and **Config validate** are the two PR-gating workflows (`dbx-config-validate` is credential-free and also runs the access-policy gate). **Validate** runs in parallel across three jobs:
- `validate (aws/azure/gcp)` matrix — `terraform fmt`, `terragrunt hclfmt`, `terragrunt validate`, Checkov, tfsec
- `infracost` — cost estimate of `infra/aws/modules`, posts result as a PR comment

**Deploy** exposes three inputs: `cloud` (aws/azure/gcp/combinations), `connectivity` (public/private), and optional `start_from_layer` (e.g. `security/iam`) for partial stack deploys.

**Destroy** has a confirmation gate job that checks `inputs.confirm == "DESTROY"` before proceeding.

---

## Known gotchas

### 1. Bootstrap is a hard prerequisite for everything

`aws/integration`, all `data_platform/*` layers across all three clouds, and `gcp/data_platform/dbx_creds` depend on outputs from `bootstrap/aws/platform` and/or `bootstrap/gcp/platform` via `dependency {}` blocks. If bootstrap hasn't been applied, `terragrunt run-all` will fail when reading those outputs from remote state (which won't exist yet).

**Required first-time order:**
```bash
make bootstrap-aws   # creates metastore, serverless workspace, SPN, KMS key, Secrets Manager secret
make bootstrap-gcp   # creates GCP metastore + workspace (GCP only)
make apply-aws
make apply-azure     # depends on bootstrap/aws/platform outputs
make apply-gcp       # depends on both bootstrap/aws/platform and bootstrap/gcp/platform
```

### 2. `deployment_id_*` must be rotated after a full destroy

`deployment_id_aws`, `deployment_id_azure`, and `deployment_id_gcp` in `config.hcl` are embedded in Databricks object names (catalogs, external locations, storage credentials). After a destroy, some Databricks control-plane objects may linger in a soft-deleted state. Re-deploying with the same suffix causes name-collision errors on those objects.

**Fix:** Update the relevant `deployment_id_*` to a new 8-character hex string before re-deploying:
```bash
openssl rand -hex 4   # generates e.g. "a3f9c1b2"
```
Then update `config.hcl` and apply. The README has a reminder note for this.

### 3. `dbx_workspace` and `managed_warehouse` are no-ops in public mode

When `is_private_connection = false` (the default), the `dbx_workspace` layers for Azure and GCP gate themselves with `for_each = local.private_mode` and create nothing. The platform uses the serverless workspace created during bootstrap instead.

If `make apply-azure` completes quickly with no `dbx_workspace` resources applied, that's expected behaviour.

### 4. Azure and GCP seed credentials are in AWS Secrets Manager

`bootstrap/gcp/foundation`, `gcp/foundation`, and several Azure/GCP layers fetch credentials from **AWS** Secrets Manager (paths `azure/bootstrap/seed_credentials`, `gcp/bootstrap/seed_credentials`). This is intentional — the bootstrap must authenticate to those clouds before their own secret stores are available.

Consequence: you need active AWS credentials (or OIDC role) even when running a Terragrunt apply that only touches Azure or GCP resources.

### 5. Infracost PR comments cover AWS infrastructure only

The `infracost` job in `dbx-validate.yml` runs against `infra/aws/modules`. The PR comment covers AWS resource types that Infracost prices (RDS, ECS, EC2, KMS, S3, VPC endpoints). It does **not** estimate:
- Databricks costs (warehouses, compute) — Infracost has no Databricks provider support
- Azure and GCP resources — limited Infracost coverage for those providers
- Any resources created via `environments/dev/` Terragrunt wiring (no resource definitions there)

The estimate is useful as a floor for infrastructure cost awareness, not a full platform cost projection.

### 6. `databricks-platform-v2` appears in git history

Workflow files and some commit messages reference `databricks-platform-v2` as a subdirectory path. This is a legacy artifact from when the project was designed as a subdirectory in a parent monorepo. The repo is now standalone (`multicloud-governance-platform`). All `working-directory` references in the current workflow files have been corrected to use repo-root-relative paths. The old name in git history is harmless — ignore it.

### 7. Checkov and tfsec scan `infra/` only

Both security scanners (in `dbx-validate.yml` and `.pre-commit-config.yaml`) target `infra/`. The `environments/dev/` Terragrunt configs are not scanned — they contain no Terraform resource definitions, only wiring (provider generation, dependency declarations, input passing). This is correct and intentional.

### 8. Governance copilot — deterministic-first, LLM bounded

The `scripts/governance_*.py` + `scripts/genie_space.py` layer is a Responsible-AI
governance copilot over the catalog (see [docs/governance/](docs/governance/README.md)).
Operational notes:

- **The analyzer is the source of truth, not Genie.** `policy_analyzer.py` runs in
  the offline `dbx-config-validate.yml` workflow and **fails the PR on any
  unacknowledged HIGH** finding. Genie only restates the analyzer's output.
- **Classification is an additive convention.** Schemas may carry
  `"classification"` (`public`|`internal`|`confidential`|`pii`) and catalogs an
  `"owner"`. Terraform ignores both — the modules consume the JSON via
  `jsondecode` + `merge`/`lookup`, so unknown keys pass through untouched. Adding
  them does **not** change any `apply`.
- **`docs/governance/` is generated, not hand-written.** `governance_report.py`,
  `genie_space.py`, `governance_metrics.py`, and `cost_estimate.py` regenerate it
  (REPORT.md, governance_context.json, genie/, metrics.json, COST.md); CI asserts
  each is in sync (`--check`). After editing any domain JSON, run
  `make governance-report` and commit the result, or the `--check` steps fail.
  `make demo` runs the whole offline pipeline; `make opa` cross-checks the gate
  with the independent Rego policy in `policy/opa/`.

- **Data pipelines (`pipelines/`) are offline and deterministic.** `make data`
  generates synthetic data (shaped by the governance model), runs a real
  bronze→silver→gold medallion in stdlib `sqlite3`, and profiles observed PII
  against declared classification → `docs/governance/data_profile.json`. The bulk
  warehouse under `pipelines/data/` is git-ignored; only the deterministic
  `data_profile.json` and the static `dashboard/index.html` are committed, and CI
  asserts both are in sync (`--check`). `make dashboard` re-renders the dashboard;
  `make demo-data` runs the whole Level-A+B flow. On the live platform the same
  transformations run as Spark SQL (`pipelines/databricks/`, deferred).
- **Exceptions are time-bound.** `environments/dev/policy_exceptions.json` entries
  have an `expires` date. An expired exception stops suppressing its finding, which
  will then fail CI — that is intentional (it forces re-review), not a bug.
