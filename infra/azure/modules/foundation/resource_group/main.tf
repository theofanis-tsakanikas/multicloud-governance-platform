# Resource to create the primary Resource Group for the data platform
resource "azurerm_resource_group" "main" {
  # Name is dynamically generated using the environment variable (e.g., rg-data-platform-prod)
  name = "rg-data-platform-${var.environment}"

  # The Azure region where the metadata for this resource group will be stored
  location = var.location
}