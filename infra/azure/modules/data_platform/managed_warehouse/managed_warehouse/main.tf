# The SQL warehouse for a PRIVATE (classic) workspace.
#
# In public mode the platform uses the serverless warehouse created during
# bootstrap, so this is never instantiated — see the `private_mode` gate in the
# parent module. `auto_stop_mins` matters: a warehouse left running is the single
# easiest way to spend money on this platform by accident.
resource "databricks_sql_endpoint" "managed" {
  name                      = var.managed_warehouse_name
  cluster_size              = var.managed_cluster_size
  max_num_clusters          = var.managed_max_num_clusters
  auto_stop_mins            = var.managed_auto_stop_mins
  enable_serverless_compute = var.managed_serverless_compute
}
