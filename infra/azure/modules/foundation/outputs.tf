output "resource_group_name" {
  description = "Resource group every downstream Azure layer deploys into."
  value       = module.resource_group.resource_group_name
}

output "adls_account_id" {
  description = "Storage account id — the scope for the SPN's role assignments."
  value       = module.adls_account.adls_account_id
}

output "adls_account_name" {
  description = "Storage account name — the abfss:// host for external locations."
  value       = module.adls_account.azure_storage_account_name
}

output "key_vault_id" {
  description = "Key Vault id — where the SPN secret and the SQL password are written."
  value       = module.key_vault.key_vault_id
}

output "key_vault_name" {
  description = "Key Vault name (carries a random suffix; see main.tf)."
  value       = module.key_vault.key_vault_name
}
