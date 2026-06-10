# Resource to create an Azure Storage Account with Data Lake capabilities
resource "azurerm_storage_account" "adls_sa_uc" {
  # Name must be globally unique across Azure, lowercase, and 3-24 characters
  name                = var.adls_name
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  account_tier        = "Standard"
  # Geo-Redundant Storage (GRS) provides durability across multiple regions
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  # This is the "magic switch" that turns standard Blob storage into ADLS Gen2
  is_hns_enabled = true
}

# Dynamic creation of storage containers within the ADLS account
resource "azurerm_storage_container" "container" {
  # Iterates through the list of container names provided in variables
  for_each           = toset(var.azure_containers)
  name               = each.key
  storage_account_id = azurerm_storage_account.adls_sa_uc.id
  # Ensuring no anonymous public access is allowed to the data
  container_access_type = "private"
}
