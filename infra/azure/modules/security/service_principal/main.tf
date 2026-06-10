# Resource to create an Azure Service Principal using Microsoft Graph API
resource "msgraph_resource" "databricks_spn" {
  # The Microsoft Graph endpoint for Service Principal management
  url = "servicePrincipals"

  # The request body linking this Service Principal to the App Registration
  body = {
    # appId represents the Client ID of the application created in earlier steps
    appId = var.app_client_id
  }

  # CRITICAL: We must extract the unique Object ID of the Service Principal
  # This ID is distinct from the Client ID and is required for Azure Role Assignments (RBAC)
  response_export_values = {
    # The 'id' field in the Graph API JSON response maps to the SPN Object ID
    spn_object_id = "id"
  }
}