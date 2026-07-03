output "schema_names" {
  description = "Map of 'database.schema' -> created Snowflake schema fully-qualified name."
  value       = { for key, s in snowflake_schema.schema : key => "${s.database}.${s.name}" }
}
