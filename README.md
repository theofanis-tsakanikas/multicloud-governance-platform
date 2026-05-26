# Databricks Multicloud Data Platform

Enterprise-grade, fully automated Databricks Unity Catalog governance across AWS, Azure, and GCP.

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

GitHub Actions workflows in `.github/workflows/` (monorepo root):

| Workflow | Trigger |
|---|---|
| `dbx-validate.yml` | Every PR touching this project |
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
