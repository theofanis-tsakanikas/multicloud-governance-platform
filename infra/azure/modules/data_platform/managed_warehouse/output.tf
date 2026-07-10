output "managed_warehouse_id" {
  description = "Id of the SQL warehouse; null in public mode."
  value       = try(module.managed_warehouse["enabled"].warehouse_id, "")
}
