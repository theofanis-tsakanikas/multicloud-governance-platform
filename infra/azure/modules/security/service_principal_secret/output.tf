output "az_spn_client_secret" {
  description = "The Client Secret for the Service Principal (Sensitive)."
  value       = azuread_application_password.spn_secret.value
  sensitive   = true
}