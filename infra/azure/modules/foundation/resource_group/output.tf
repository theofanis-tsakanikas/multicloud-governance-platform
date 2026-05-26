output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "The name of the created Resource Group"
}

output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "The Resource ID of the Resource Group (useful for IAM Role Assignments)"
}

