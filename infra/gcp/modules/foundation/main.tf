# GCP foundation — enable the APIs, then create the bucket everything else writes to.
#
# Ordering matters and is not implicit: google_storage_bucket will 403 if the
# Storage API has not been enabled on the project yet, and Terraform cannot infer
# that dependency from the resource graph.

module "gcp_services" {
  source       = "./gcp_services"
  project_id   = var.project_id
  service_list = var.service_list
}

module "gcs_bucket" {
  source     = "./gcs_bucket"
  project_id = var.project_id
  location   = var.location

  # Bucket names are globally unique across all of GCS; the prefix alone is not.
  bucket_name = "${var.bucket_prefix_name}-${var.project_id}"

  depends_on = [module.gcp_services]
}
