resource "google_storage_bucket" "this" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.location
  force_destroy = true # Allows terraform to delete the bucket even if it contains objects

  storage_class = "STANDARD"

  # Required for Unity Catalog: All permissions are managed via IAM, not ACLs
  uniform_bucket_level_access = true

  # Checkov CKV_GCP_114, and it is not the same thing as the line above.
  #
  # `uniform_bucket_level_access` turns OFF per-object ACLs — it decides *how* permissions are
  # expressed. It does not decide *who* they can be given to: an IAM binding to `allUsers` is still
  # perfectly legal on a uniform bucket, and it makes the whole thing world-readable.
  #
  # `public_access_prevention = "enforced"` is the one that refuses. It rejects any binding to
  # allUsers or allAuthenticatedUsers outright, at the API, no matter who asks. On a bucket holding
  # a governed data lake, the ability to make it public is not a feature anyone needs.
  public_access_prevention = "enforced"

  # Recommended: Keeps a history of objects to prevent accidental data loss
  versioning {
    enabled = true
  }

  # Labels to help track and organize resources
  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
