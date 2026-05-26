output "key_vault_id" {
  value       = azurerm_key_vault.main.id
  description = "The Resource ID of the Key Vault. Needed for resource associations."
}

output "key_vault_uri" {
  value       = azurerm_key_vault.main.vault_uri
  description = "The URI of the Key Vault, used for accessing secrets via SDKs/Python."
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "The name of the Key Vault."
}