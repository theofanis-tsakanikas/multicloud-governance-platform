output "storage_credential_external_id" {
  value = databricks_storage_credential.creds.aws_iam_role[0].external_id
}

output "storage_credential_name" {
  value = databricks_storage_credential.creds.id
}
