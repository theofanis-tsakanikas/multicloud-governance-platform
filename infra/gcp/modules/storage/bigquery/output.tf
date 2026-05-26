output "dataset_ids" {
  value = [for d in google_bigquery_dataset.dataset : d.dataset_id]
}