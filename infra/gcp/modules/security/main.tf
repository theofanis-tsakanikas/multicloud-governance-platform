# GCP security — grant the two Databricks identities access to the bucket.
#
# The GCP counterpart of AWS `security/iam` and Azure `security`. There is no
# credential to create here: Databricks on GCP authenticates with its own
# Google-managed service accounts, and governance only has to grant them the
# object-level access Unity Catalog needs.

module "service_account" {
  source           = "./service_account"
  project_id       = var.project_id
  gcs_bucket_name  = var.gcs_bucket_name
  dbx_sa_email     = var.dbx_sa_email
  uc_sa_email      = var.uc_sa_email
  federation_sa_id = var.federation_sa_id
  bq_secret_id     = var.bq_secret_id
}
