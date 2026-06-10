# Resource to create an Azure App Registration via Microsoft Graph API
resource "msgraph_resource" "databricks_app" {
  # The Graph API endpoint for application objects
  url = "applications"

  # The request body containing the application's configuration
  body = {
    # The human-readable name for the application in the Entra ID portal
    displayName = var.databricks_app_name
  }

  # Exporting critical identifiers from the Graph API response
  response_export_values = {
    # appId (Client ID): Used for authentication/login
    client_id_export = "appId"
    # id (Object ID): Used for managing the application object itself
    object_id_export = "id"
  }
}

# Resource to store the Application's Client ID in Azure Key Vault
resource "azurerm_key_vault_secret" "spn_id" {
  # The secret name that external services will use to look up the ID
  name = "az-spn-client-id"
  # Pulls the exported appId from the msgraph resource output
  value        = msgraph_resource.databricks_app.output.client_id_export
  key_vault_id = var.key_vault_id
}