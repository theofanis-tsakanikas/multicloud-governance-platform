# Resource to define authentication for Azure Data Lake Storage (ADLS) Gen2
resource "databricks_storage_credential" "azure_adls_creds" {
  # Unique name combining the base credential name and deployment ID
  name = "${var.azure_storage_credential_name}_${var.deployment_id}"

  # Azure-specific authentication using a Service Principal (SPN)
  azure_service_principal {
    # The Azure Tenant (Directory) ID where the SPN is registered
    directory_id = var.azure_tenant_id
    # The Application (Client) ID of the Service Principal
    application_id = var.az_spn_client_id
    # The Client Secret for the Service Principal (should be marked sensitive)
    client_secret = var.az_spn_client_secret
  }

  # Description of the credential's purpose for Unity Catalog documentation
  comment = "Credential used for accessing Azure ADLS Gen2 from AWS Databricks"
}