# Fetches the configuration of the current Azure provider (Tenant, Client, Subscription IDs)
data "azurerm_client_config" "current" {}

locals {
  # List of identities (The current user/SPN and the Orchestrator) that require full access
  privileged_ids = [
    data.azurerm_client_config.current.object_id,
    var.orchestrator_object_id
  ]
}

# Resource to create the Azure Key Vault for centralized secret management
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Note: Soft delete and purge protection can be enabled here for production data
  # soft_delete_retention_days  = 7
  # purge_protection_enabled    = false
}

# Grants legacy Access Policy permissions to the privileged identities
resource "azurerm_key_vault_access_policy" "main_access" {
  # Iterates through the list of privileged IDs defined in locals
  for_each = toset(local.privileged_ids)

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  # Comprehensive permissions for secret lifecycle management
  secret_permissions  = ["Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"]
  key_permissions     = ["Get", "List", "Create"]
  storage_permissions = ["Get"]
}

# NOTE: no azurerm_role_assignment here.
#
# This vault is access-policy based -- `enable_rbac_authorization` is unset, which
# means false -- so the access policies above are what actually govern access. A
# "Key Vault Secrets User" role assignment would grant nothing extra, while
# requiring `Microsoft.Authorization/roleAssignments/write` from whoever runs the
# apply. Least privilege applies to the deployer too.