output "database_names" {
  description = "Map of catalog_name -> created Snowflake database name."
  value       = { for name, db in snowflake_database.db : name => db.name }
}
