output "adls_account_id" {
  description = "The ID of the ADLS Storage Account."
  value       = azurerm_storage_account.adls_sa_uc.id
}

output "azure_storage_account_name" {
  description = "The name of the ADLS Storage Account (used in the URL)."
  value       = azurerm_storage_account.adls_sa_uc.name
}

output "containers_map" {
  description = "A map of container keys to their actual names"
  value       = { for k, c in azurerm_storage_container.container : k => c.name }
}