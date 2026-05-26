resource "google_storage_bucket" "this" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.location
  force_destroy = true # Allows terraform to delete the bucket even if it contains objects

  storage_class = "STANDARD"

  # Required for Unity Catalog: All permissions are managed via IAM, not ACLs
  uniform_bucket_level_access = true

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
