# Global configuration for the dev environment.
# Replaces config.json — referenced by all child terragrunt.hcl files.

locals {
  environment = "dev"

  # ─── AWS ─────────────────────────────────────────────────────────────────
  aws_account_id     = "387229419515"
  dbx_aws_account_id = "414351767826"

  # Serverless PrivateLink runs out of a DIFFERENT Databricks-owned AWS account than the
  # workspace cross-account role above, and the role it uses carries the region in its name:
  #   arn:aws:iam::565502421330:role/private-connectivity-role-<region>
  # Databricks validates that this exact ARN is on the endpoint service's allow-list before it
  # will even attempt the endpoint, so a wildcard does not satisfy it and neither does the
  # workspace account. https://docs.databricks.com/aws/en/security/network/serverless-network-security/pl-to-internal-network
  dbx_serverless_privatelink_account_id = "565502421330"
  aws_region                            = "eu-central-1"
  bucket_name                           = "dbx-de-project-bucket-2026"
  iam_role_name                         = "databricks-access-role"
  is_private_connection_aws             = get_env("PRIVATE_AWS", "false") == "true" # per-cloud connectivity — set by the deploy workflow (skip/public/private)
  is_private_connection_azure           = get_env("PRIVATE_AZURE", "false") == "true"
  is_private_connection_gcp             = get_env("PRIVATE_GCP", "false") == "true"

  # RDS
  rds_username           = "sales_admin"
  db_instance_class      = "db.t3.micro"
  db_engine              = "postgres"
  engine_version         = "15"
  allocated_storage      = 20
  rds_port               = 5432
  password_name          = "sales/rds-secret"
  db_instance_identifier = "sales-db-instance"
  db_name                = "salesdb"
  rds_connection_name    = "rds_postgres_conn"
  rds_vpc_cidr           = "10.40.0.0/16"
  rds_subnets_config     = { subnet_a = "10.40.1.0/24", subnet_b = "10.40.2.0/24" }
  private_dns_zone_name  = "db.internal"
  rds_custom_dns_name    = "postgres.db.internal"
  ecr_repo_name          = "pgbouncer-gateway"

  # ─── Databricks ──────────────────────────────────────────────────────────
  dbx_account_id     = "0be655cb-910d-4e79-909e-b8e98e3c783b"
  databricks_host    = "https://accounts.cloud.databricks.com"
  delta_sharing_name = "aws_delta_share"

  # Bootstrap Secrets ARN (seed credentials for first-time setup)
  seed_credentials_arn = "arn:aws:secretsmanager:eu-central-1:387229419515:secret:databricks/bootstrap/seed_credentials-juiFEF"
  seed_credentials_id  = "databricks/bootstrap/seed_credentials"
  spn_secret_id        = "databricks/spn/dev/spn_credentials"

  # Bootstrap config
  metastore_iam_role_name      = "dbx-metastore-role"
  cross_account_role_name      = "dbx-cross-account-role"
  metastore_bucket_name        = "dbx-metastore-root"
  workspace_name               = "serverless-workspace"
  metastore_name               = "primary-metastore-eu-central-1"
  secret_base_path             = "databricks/spn"
  secret_recovery_window       = 0
  kms_deletion_window          = 7
  delta_sharing_token_lifetime = 7776000
  spn_suffix                   = "terraform-admin-spn"
  warehouse_prefix             = "serverless_warehouse"
  warehouse_permission_level   = "CAN_MANAGE"
  auto_stop_mins               = 10
  max_num_clusters             = 1
  warehouse_access_groups      = ["data_engineers"]
  warehouse_size               = "2X-Small"
  workspace_pricing_tier       = "ENTERPRISE"
  metastore_admins_aws         = ["79066160746664", "77102429556016"]   # AWS Databricks account: you + AWS automation SP
  metastore_admins_gcp         = ["214315615769184", "212919085861654"] # GCP Databricks account: you + GCP automation SP
  identity_groups              = ["data_engineers", "data_scientists", "analysts", "business_users", "marketing_scientists", "marketing_analysts", "crm_managers"]
  admin_group_name             = "metastore_admins"

  # ─── Azure ───────────────────────────────────────────────────────────────
  azure_location        = "West Europe"
  prefix_key_vault_name = "kv-datalake"
  admin_object_id       = "56ddbe8e-1f5f-4dd7-bb84-92ea9c3d7495"
  adls_name             = "adls"
  # One container per platform, mirroring the single S3 bucket on AWS. The zone
  # (raw / managed / gold) is a path inside it, exactly as the domain JSON
  # declares: abfss://databricks-project@<acct>/supply-chain/raw/
  azure_containers    = ["databricks-project"]
  databricks_app_name = "databricks-connector"
  role_names          = ["Storage Blob Data Contributor", "Reader"]
  sql_server_name     = "sql-federation-master"
  sql_admin_user      = "sql_vault_admin"
  sql_password_name   = "sql-admin-password"
  # Must match `database_name` on the FEDERATED catalog in
  # domains/azure/supply_infra.json — that value becomes the foreign catalog's
  # `database` option, and the JDBC connection opens against it. "salesdb" was
  # copied from the AWS config and named the wrong domain entirely.
  sql_database_name             = "sqldb-product-catalog"
  mssql_port                    = 1433
  vnet_name                     = "vnet-data-platform"
  azure_vnet_cidr               = ["10.20.0.0/16"]
  data_subnet_prefix            = ["10.20.1.0/24"]
  endpoint_subnet_prefix        = ["10.20.2.0/24"]
  gateway_subnet_prefix         = ["10.20.255.0/27"]
  databricks_vpc_cidr           = "10.10.0.0/16"
  databricks_subnets            = { subnet_a = "10.10.1.0/24", subnet_b = "10.10.2.0/24" }
  azure_seed_secret_arn         = "arn:aws:secretsmanager:eu-central-1:387229419515:secret:azure/bootstrap/seed_credentials-Pe2FJ6"
  azure_storage_credential_name = "azure_federation_creds"

  # ─── GCP ─────────────────────────────────────────────────────────────────
  gcp_project_id         = "databricks-multicloud-platform"
  gcp_project_number     = "810048527282"
  gcp_location           = "europe-west3"
  gcp_bucket_prefix_name = "databricks-gcp-bucket"
  gcp_vpc_cidr           = ["10.30.0.0/16", "199.36.153.4/30"]
  gcp_subnet_cidr        = ["10.30.1.0/24"]
  network_name           = "gcp-dbx-vpc"
  subnetwork_name        = "gcp-dbx-subnet"
  terraform_sa_account   = "terraform-deployer@databricks-multicloud-platform.iam.gserviceaccount.com"
  dbx_system_sa_gcp      = "dabc-d7f3c69a3d414b638430c29ab7771451@gcp-sa-databricks.iam.gserviceaccount.com"
  gcp_dbx_account_id     = "d7f3c69a-3d41-4b63-8430-c29ab7771451"
  gcp_databricks_host    = "https://accounts.gcp.databricks.com"
  gcp_workspace_name     = "gcp-serverless-workspace"
  gcp_metastore_name     = "primary-metastore-europe-west3"
  gcp_metastore_bucket   = "dbx-metastore-bucket"
  gcp_delta_sharing_name = "gcp_delta_share"
  # Delta Sharing between two Databricks accounts: the GCP metastore creates a
  # recipient for the AWS metastore, and the AWS side then sees a provider of
  # this name automatically. Nothing creates the provider object explicitly.
  aws_db_recipient             = "aws_metastore_recipient"
  gcp_provider_name            = "gcp_delta_provider"
  dbx_sa_name                  = "dbx-sa"
  gcp_dbx_account_creds_secret = "projects/810048527282/secrets/seed_credentials"
  gcp_sa_secret_id             = "bq_key"
  gcp_wif_pool_id              = "wif-db-pool"
  gcp_provider_id              = "databricks-oidc-provider"
  gcp_service_account_id       = "dbx-federation-sa"
  gcp_seed_secret_arn          = "arn:aws:secretsmanager:eu-central-1:387229419515:secret:gcp/bootstrap/seed_credentials-GGd5LM"
  gcp_storage_credential_name  = "gcp-databricks-creds"
  gcp_service_list = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com"
  ]

  # ─── Snowflake (second enforcement backend — engine-agnostic governance) ──
  # Identifiers only (no secrets); auth is via a ~/.snowflake/config.toml profile
  # or SNOWFLAKE_* env vars at plan/apply time. The storage integration is
  # provisioned by a creds/bootstrap layer and referenced here by name.
  snowflake_organization             = "SNOWFLAKE_ORG_REDACTED"
  snowflake_account                  = "SNOWFLAKE_ACCOUNT_REDACTED"
  snowflake_storage_integration_name = "DEV_STORAGE_INTEGRATION"
  snowflake_warehouse_size           = "XSMALL"
  snowflake_credit_quota             = 100

  # ─── Git (Snowflake reads the notebooks from the repo — ADR-0015) ─────────
  # Public identifiers, not secrets. The owner URL is what the API integration is
  # allowed to call: scoped to this owner, not to all of GitHub.
  github_owner_url = "https://github.com/theofanis-tsakanikas"
  github_repo_url  = "https://github.com/theofanis-tsakanikas/multicloud-governance-platform"

  # CREATE GIT REPOSITORY clones. Against a private repo it fails outright, so the object waits
  # for the fact it depends on. Flip this the day the repo is made public; nothing else changes.
  github_repo_is_public = false

}
