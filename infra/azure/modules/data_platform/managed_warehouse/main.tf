# A SQL warehouse is only needed when the platform runs a PRIVATE (classic)
# workspace. In public mode the serverless warehouse created during bootstrap is
# used, and this layer is a no-op — the same gate dbx_workspace uses.

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "managed_warehouse" {
  for_each = local.private_mode
  source   = "./managed_warehouse"

  managed_warehouse_name     = var.managed_warehouse_name
  managed_cluster_size       = var.managed_cluster_size
  managed_max_num_clusters   = var.managed_max_num_clusters
  managed_auto_stop_mins     = var.managed_auto_stop_mins
  managed_serverless_compute = var.managed_serverless_compute

  providers = {
    databricks = databricks.uc_mws
  }
}
