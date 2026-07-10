output "az_spn_client_id" {
  description = "Client id of the app registration; consumed by dbx_creds."
  value       = module.spn_application.az_spn_client_id
}

output "az_spn_client_secret" {
  description = "Client secret; consumed by dbx_creds. Also written to Key Vault."
  value       = module.service_principal_secret.az_spn_client_secret
  sensitive   = true
}

output "spn_object_id" {
  description = "Object id of the service principal."
  value       = module.service_principal.spn_object_id
}
