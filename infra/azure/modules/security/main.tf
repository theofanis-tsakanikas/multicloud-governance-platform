# Azure security — the service principal Unity Catalog uses to reach ADLS.
#
# The counterpart of the AWS `security/iam` layer: AWS gives Databricks a role to
# assume, Azure gives it an app registration with a client secret. Neither secret
# is ever stored in this repo — the secret is written straight into Key Vault and
# read back at plan time via `run_cmd az keyvault secret show`.
#
# The chain is strictly ordered and each step needs the previous one's identifier:
#
#   spn_application  (app registration)      -> client id
#     service_principal (SP for that app)    -> object id
#       role_assignment (Storage Blob Data)  -> scoped to the ADLS account
#     service_principal_secret               -> secret, into Key Vault

module "spn_application" {
  source              = "./spn_application"
  databricks_app_name = var.databricks_app_name
  key_vault_id        = var.key_vault_id
}

module "service_principal" {
  source        = "./service_principal"
  app_client_id = module.spn_application.az_spn_client_id
}

module "service_principal_secret" {
  source                    = "./service_principal_secret"
  environment               = var.environment
  databricks_application_id = module.spn_application.databricks_application_id
  key_vault_id              = var.key_vault_id
}

# Least privilege: the SPN is granted the named data-plane roles on the storage
# account only, never at subscription scope.
module "role_assignment" {
  source          = "./role_assignment"
  adls_account_id = var.adls_account_id
  spn_object_id   = module.service_principal.spn_object_id
  role_names      = var.role_names
}
