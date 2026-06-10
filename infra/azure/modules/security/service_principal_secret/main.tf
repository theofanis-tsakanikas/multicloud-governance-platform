# Resource to generate a new Client Secret (Password) for the App Registration
resource "azuread_application_password" "spn_secret" {
  # References the Application ID using the required Graph API path format
  application_id = format("/applications/%s", var.databricks_application_id)
  # Unique display name to identify this secret in the Entra ID portal
  display_name = "databricks-secret-${var.environment}"
}



# Resource to securely store the generated secret in Azure Key Vault
resource "azurerm_key_vault_secret" "spn_secret" {
  # The identifier used by the orchestrator or Databricks to fetch this secret
  name = "az-spn-client-secret"
  # Pulls the sensitive value directly from the resource above
  value        = azuread_application_password.spn_secret.value
  key_vault_id = var.key_vault_id
}