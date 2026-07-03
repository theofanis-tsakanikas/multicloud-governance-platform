output "role_names" {
  description = "Map of governance principal -> Snowflake functional role name (for grant targeting)."
  value       = { for principal, role in snowflake_account_role.functional : principal => role.name }
}
