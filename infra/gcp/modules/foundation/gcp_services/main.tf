resource "google_project_service" "enabled_services" {
  for_each = toset(var.service_list)
  project  = var.project_id
  service  = each.key

  disable_on_destroy = false
}