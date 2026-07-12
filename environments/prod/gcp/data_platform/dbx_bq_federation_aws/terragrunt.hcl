# BigQuery, federated into the AWS serverless workspace — the consumer the transit hub was missing.
#
# The sibling dbx_bq_connector points at the GCP workspace, because the GCP medallion runs there.
# This one points at the AWS workspace: the one that already federates RDS over PrivateLink and
# Azure SQL over the transit hub, and that until now had no reason to call BigQuery at all.
#
# With this leaf, every query it makes against marketing_bq_fed leaves through the NCC private
# endpoint, the PrivateLink service, the gateway, the VPN, and Google's private API VIP — the path
# gcp/integration builds. One workspace, three sources, three private paths.

include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  # The AWS Databricks SPN — this catalog lives in the AWS workspace, not the GCP one.
  spn = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))

  domain_path        = "${get_terragrunt_dir()}/../../../domains/gcp"
  infra              = jsondecode(file("${local.domain_path}/marketing_infra.json"))
  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
}

# The federation service-account key.
dependency "security" {
  config_path = "../../security"
}

# The AWS serverless workspace this catalog is created in.
dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

# The transit hub must exist before a query can cross it. In public mode this layer is a no-op and
# the dependency costs nothing.
dependency "integration" {
  config_path = "../../integration"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//dbx_bq_federation_aws"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      # The AWS workspace. Auth method named explicitly, so a stray ARM_* credential cannot make
      # the provider see two and refuse to choose.
      auth_type     = "oauth-m2m"
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
  EOF
}

inputs = {
  spn_client_id     = local.spn.client_id
  spn_client_secret = local.spn.client_secret

  connection_name = local.federated_catalogs[0].connection_name
  catalog_name    = local.federated_catalogs[0].catalog_name
  project_id      = local.cfg.gcp_project_id
  bq_key          = dependency.security.outputs.bq_sa_key
  reader_groups   = ["data_engineers"]
}
