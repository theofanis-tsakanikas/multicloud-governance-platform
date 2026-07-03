variable "grant_instances" {
  description = <<-EOT
    Fully-resolved Snowflake grant instances, produced by the wrapper module by translating
    the domain grants through infra/snowflake/privilege_map.json. Each instance:
      {
        key         = unique string
        role_name   = target Snowflake functional role
        privileges  = list of Snowflake privileges
        kind        = "database" | "schema" | "schema_tables_all" | "schema_tables_future" | "stage"
        object_name = fully-qualified object (DATABASE name, or STAGE "db.schema.stage")
        schema      = "db.schema" (for schema / schema_tables_* kinds)
      }
  EOT
  type        = any
  default     = []
}
