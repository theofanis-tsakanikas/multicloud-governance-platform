

module "dbx_bq_connector" {
  source           = "./dbx_bq_connector"
  connection_name  = var.connection_name
  project_id       = var.project_id
  cred_sa_email    = var.cred_sa_email
  bq_key           = var.bq_key
  admin_group_name = var.admin_group_name
}