# Databricks Multicloud Data Platform

[![CI](https://github.com/theofanis-tsakanikas/databricks-uc-multicloud-platform/actions/workflows/dbx-validate.yml/badge.svg)](https://github.com/theofanis-tsakanikas/databricks-uc-multicloud-platform/actions/workflows/dbx-validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.10-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-%E2%89%A50.75-4CADE3)](https://terragrunt.gruntwork.io/)
[![Databricks](https://img.shields.io/badge/Databricks-Unity%20Catalog-FF3621?logo=databricks&logoColor=white)](https://www.databricks.com/)
[![Cloud](https://img.shields.io/badge/Cloud-AWS%20%7C%20Azure%20%7C%20GCP-orange)](https://github.com/theofanis-tsakanikas/databricks-uc-multicloud-platform)

Enterprise-grade, fully automated Databricks Unity Catalog governance across AWS, Azure, and GCP.

---

## Table of contents

- [What this demonstrates](#what-this-demonstrates)
- [Architecture](#architecture)
- [Stack](#stack)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [CI/CD](#cicd)
- [Adding a new domain](#adding-a-new-domain)
- [After a full destroy](#after-a-full-destroy)

---

## What this demonstrates

This project is a reference implementation of production-grade, multi-cloud data platform provisioning. It was built to demonstrate the following engineering patterns:

| Pattern | Implementation |
|---|---|
| **Multi-cloud IaC without a custom orchestrator** | Terragrunt `dependency {}` blocks build a DAG across all layers and clouds; `run-all apply` executes in correct order automatically |
| **Zero-Python domain governance** | Unity Catalog schemas, grants, and external locations are defined in JSON and wired to Terraform via `jsondecode(file(...))` — no code generation step |
| **Secrets never in code** | `run_cmd` fetches all secrets from AWS Secrets Manager at plan time; no secrets in state, no env var injection |
| **OIDC-based CI with no long-lived credentials** | GitHub Actions assumes an AWS IAM role via OIDC; Azure uses federated identity; GCP seeds from AWS Secrets Manager |
| **Cross-cloud Delta Sharing** | GCP marketing catalog is shared to the AWS metastore using dual Databricks provider aliases and native HCL logic |
| **Security scanning in CI** | Checkov and tfsec run on every PR against `infra/`; pre-commit hooks enforce the same checks locally |
| **Cost estimation in CI** | Infracost posts an AWS infrastructure cost breakdown as a PR comment on every change |

Full architecture detail, dependency graphs, and design decisions are in [ARCHITECTURE.md](ARCHITECTURE.md). Operational gotchas and secrets flow are in [CLAUDE.md](CLAUDE.md).

---

## Architecture

| Layer | AWS | Azure | GCP |
|---|---|---|---|
| Foundation | S3 + KMS + ECR | ADLS Gen2 + Key Vault | GCS + IAM |
| Security | IAM + Secrets Manager | Service Principal | Service Account + WIF |
| Network | VPC + RDS subnets | VNet + Subnets | VPC + Subnets |
| Storage | RDS PostgreSQL 15 | Azure SQL (MSSQL) | BigQuery |
| Integration | ECS/PgBouncer + NCC | VNet Peering | BigQuery Connector |
| Data Platform | Storage Creds + Connectors + Governance | ← | ← |

## Stack

- **Terragrunt** orchestrates Terraform layers with automatic dependency resolution
- **Remote state** in S3 with DynamoDB locking
- **Secrets** fetched at plan/apply time from AWS Secrets Manager — never stored in code
- **Domain governance** defined in JSON, loaded natively by Terragrunt — no custom code

## Prerequisites

- Terraform ≥ 1.10
- Terragrunt ≥ 0.75
- AWS CLI configured (with access to `387229419515`)
- Bootstrap completed (`make bootstrap-aws`)

## Quick start

```bash
# First time only — bootstrap the Databricks account
make bootstrap-aws
make bootstrap-gcp

# Preview what will be deployed
make plan-aws

# Deploy
make apply-aws

# Deploy a single layer
make apply LAYER=aws/security/iam

# Destroy (confirms before running)
make destroy-aws
```

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

| Workflow | Trigger |
|---|---|
| `dbx-validate.yml` | Every PR touching `infra/**`, `environments/**`, or `terragrunt.hcl` |
| `dbx-bootstrap.yml` | Manual: bootstrap AWS or GCP |
| `dbx-deploy.yml` | Manual: deploy one or all clouds |
| `dbx-destroy.yml` | Manual: destroy with "DESTROY" confirmation |

Required GitHub secrets: `DBX_DEPLOY_ROLE_ARN`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

## Adding a new domain

1. Add `environments/dev/domains/<cloud>/<domain>_infra.json`
2. Add `environments/dev/domains/<cloud>/<domain>_grants.json`
3. Update the `domain_path` locals in the relevant `data_platform/dbx_governance/terragrunt.hcl`
4. Run `make apply LAYER=<cloud>/data_platform/dbx_governance`

## After a full destroy

Update `deployment_id_<cloud>` in `environments/dev/config.hcl` to prevent resource name collisions on re-deploy.
