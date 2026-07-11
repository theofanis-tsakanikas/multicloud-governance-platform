# Global configuration for the prod environment.
#
# Production runs in DEDICATED cloud accounts/projects/subscriptions — the
# placeholder identifiers below (account IDs, ARNs, object IDs) must be replaced
# with the production tenancy values before the first apply. Everything else
# (naming, CIDR layout, layer wiring) intentionally mirrors dev so promotion is
# a config diff, not an architecture change.

locals {
  environment = "prod"

  # ─── AWS ─────────────────────────────────────────────────────────────────
  aws_account_id     = "111111111111" # TODO: production AWS account
  dbx_aws_account_id = "414351767826"

  # Serverless PrivateLink runs out of a DIFFERENT Databricks-owned AWS account than the
  # workspace cross-account role above, and the role it uses carries the region in its name:
  #   arn:aws:iam::565502421330:role/private-connectivity-role-<region>
  # Databricks validates that this exact ARN is on the endpoint service's allow-list before it
  # will even attempt the endpoint, so a wildcard does not satisfy it and neither does the
  # workspace account. https://docs.databricks.com/aws/en/security/network/serverless-network-security/pl-to-internal-network
  dbx_serverless_privatelink_account_id = "565502421330"
  aws_region                            = "eu-central-1"
  bucket_name                           = "dbx-de-project-bucket-prod"
  iam_role_name                         = "databricks-access-role"
  is_private_connection_aws             = get_env("PRIVATE_AWS", "false") == "true" # per-cloud connectivity — set by the deploy workflow (skip/public/private)
  is_private_connection_azure           = get_env("PRIVATE_AZURE", "false") == "true"
  is_private_connection_gcp             = get_env("PRIVATE_GCP", "false") == "true"

  # RDS
  rds_username           = "sales_admin"
  db_instance_class      = "db.m5.large"
  db_engine              = "postgres"
  engine_version         = "15"
  allocated_storage      = 20
  rds_port               = 5432
  password_name          = "sales/rds-secret"
  db_instance_identifier = "sales-db-instance-prod"
  db_name                = "salesdb"
  rds_connection_name    = "rds_postgres_conn"
  rds_vpc_cidr           = "10.40.0.0/16"
  rds_subnets_config     = { subnet_a = "10.40.1.0/24", subnet_b = "10.40.2.0/24" }
  private_dns_zone_name  = "db.internal"
  rds_custom_dns_name    = "postgres.db.internal"
  ecr_repo_name          = "pgbouncer-gateway"

  # ─── Databricks ──────────────────────────────────────────────────────────
  dbx_account_id     = "00000000-0000-0000-0000-000000000000" # TODO: production Databricks account
  databricks_host    = "https://accounts.cloud.databricks.com"
  delta_sharing_name = "aws_delta_share"

  # Bootstrap Secrets ARN (seed credentials for first-time setup)
  seed_credentials_arn = "arn:aws:secretsmanager:eu-central-1:111111111111:secret:databricks/bootstrap/seed_credentials-XXXXXX" # TODO
  seed_credentials_id  = "databricks/bootstrap/seed_credentials"
  spn_secret_id        = "databricks/spn/prod/spn_credentials"

  # Bootstrap config
  metastore_iam_role_name      = "dbx-metastore-role"
  cross_account_role_name      = "dbx-cross-account-role"
  metastore_bucket_name        = "dbx-metastore-root-prod"
  workspace_name               = "serverless-workspace-prod"
  metastore_name               = "primary-metastore-eu-central-1"
  secret_base_path             = "databricks/spn"
  secret_recovery_window       = 7
  kms_deletion_window          = 7
  delta_sharing_token_lifetime = 7776000
  spn_suffix                   = "terraform-admin-spn"
  warehouse_prefix             = "serverless_warehouse"
  warehouse_permission_level   = "CAN_MANAGE"
  auto_stop_mins               = 30
  max_num_clusters             = 1
  warehouse_access_groups      = ["data_engineers"]
  warehouse_size               = "Small"
  workspace_pricing_tier       = "ENTERPRISE"
  metastore_admins_aws         = ["79066160746664"]                     # AWS Databricks account only
  metastore_admins_gcp         = ["214315615769184", "212919085861654"] # GCP Databricks account (replace for prod tenancy)
  identity_groups              = ["data_engineers", "data_scientists", "analysts", "business_users", "marketing_scientists", "marketing_analysts", "crm_managers"]
  admin_group_name             = "metastore_admins"

  # ─── Azure ───────────────────────────────────────────────────────────────
  azure_location        = "West Europe"
  prefix_key_vault_name = "kv-datalake"
  admin_object_id       = "00000000-0000-0000-0000-000000000000" # TODO: production Entra admin object id
  adls_name             = "adls"
  # One container per platform, mirroring the single S3 bucket on AWS. The zone
  # (raw / managed / gold) is a path inside it, exactly as the domain JSON
  # declares: abfss://databricks-project@<acct>/supply-chain/raw/
  azure_containers    = ["databricks-project"]
  databricks_app_name = "databricks-connector"
  role_names          = ["Storage Blob Data Contributor", "Reader"]
  sql_server_name     = "sql-federation-master-prod"
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
  azure_seed_secret_arn         = "arn:aws:secretsmanager:eu-central-1:111111111111:secret:azure/bootstrap/seed_credentials-XXXXXX" # TODO
  azure_storage_credential_name = "azure_federation_creds"

  # ─── GCP ─────────────────────────────────────────────────────────────────
  gcp_project_id         = "databricks-multicloud-platform"
  gcp_project_number     = "810048527282"
  gcp_location           = "europe-west3"
  gcp_bucket_prefix_name = "databricks-gcp-bucket"
  gcp_vpc_cidr           = ["10.30.0.0/16", "199.36.153.8/30"]
  gcp_subnet_cidr        = ["10.30.1.0/24"]

  # GCP's own AWS transit VPC. It cannot share Azure's 10.10.0.0/16: two VPCs with the same CIDR
  # in one account are legal but unroutable to each other and impossible to reason about, and the
  # Azure hub is live and working — nothing here may touch it.
  gcp_transit_vpc_cidr = "10.11.0.0/16"
  gcp_transit_subnets  = { subnet_a = "10.11.1.0/24", subnet_b = "10.11.2.0/24" }
  gcp_transit_nat_cidr = "10.11.100.0/24"
  gcp_ecr_repo_name    = "bq-gateway"

  # The private.googleapis.com VIP. NOT restricted.googleapis.com (199.36.153.4/30): that one only
  # fronts APIs that support VPC Service Controls, and the BigQuery connector also needs
  # oauth2.googleapis.com to exchange its service-account key for a token. private.googleapis.com
  # fronts essentially every Google API, which is what a private path without VPC-SC requires.
  gcp_private_api_vip_cidr = "199.36.153.8/30"
  gcp_private_api_vip_ips  = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
  network_name             = "gcp-dbx-vpc"
  subnetwork_name          = "gcp-dbx-subnet"
  terraform_sa_account     = "terraform-deployer@databricks-multicloud-platform.iam.gserviceaccount.com"
  dbx_system_sa_gcp        = "dabc-d7f3c69a3d414b638430c29ab7771451@gcp-sa-databricks.iam.gserviceaccount.com"
  gcp_dbx_account_id       = "d7f3c69a-3d41-4b63-8430-c29ab7771451"
  gcp_databricks_host      = "https://accounts.gcp.databricks.com"
  gcp_workspace_name       = "gcp-serverless-workspace-prod"
  gcp_metastore_name       = "primary-metastore-europe-west3"
  gcp_metastore_bucket     = "dbx-metastore-bucket"
  gcp_delta_sharing_name   = "gcp_delta_share"
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
  gcp_seed_secret_arn          = "arn:aws:secretsmanager:eu-central-1:111111111111:secret:gcp/bootstrap/seed_credentials-XXXXXX" # TODO
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

}
