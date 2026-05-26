

module "managed_warehouse" {
  source                     = "./managed_warehouse"
  managed_warehouse_name     = var.managed_warehouse_name
  managed_cluster_size       = var.managed_cluster_size
  managed_max_num_clusters   = var.managed_max_num_clusters
  managed_auto_stop_mins     = var.managed_auto_stop_mins
  managed_serverless_compute = var.managed_serverless_compute

  providers = {
    databricks = databricks.uc_mws
  }
}