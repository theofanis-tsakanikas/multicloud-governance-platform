# Databricks provider configuration for Unity Catalog administration




# Necessary delay to ensure IAM roles and trust relationships have 
# fully propagated across AWS and Databricks global APIs.
resource "time_sleep" "iam_propagation" {
  create_duration = "60s"
}

locals {
  # Decode raw JSON strings provided by Python into Terraform-native structures
  external_locations_data    = jsondecode(var.external_locations_json)
  ext_loc_grants_data        = jsondecode(var.ext_loc_grants_json)
  catalogs_data              = jsondecode(var.catalogs_json)
  catalog_grants_data        = jsondecode(var.catalog_grants_json)
  managed_schema_grants_data = jsondecode(var.managed_schema_grants_json)
  volume_grants_data         = jsondecode(var.volume_grants_json)

  # --- AWS URL Calculation ---
  # In AWS we use the format: s3://bucket-name/path
  loc_map = {
    for loc in local.external_locations_data : loc.location_name => merge(loc, {
      # Remove trailing slashes and append exactly one for a clean S3 URI
      calculated_url = "s3://${var.bucket_name}/${trim(loc.path, "/")}/${var.deployment_id_aws}/"

      # Calculate a Unique Name (Injecting the deployment_id_aws)
      # If loc.location_name is "sales_raw", the final name will be "sales_raw_a1b2c3d4"
      unique_name = "${loc.location_name}_${var.deployment_id_aws}"
    })
  }

  catalog_map = { for cat in local.catalogs_data : cat.catalog_name => cat }

  # Enrich catalog data with specific AWS S3 URIs for storage roots
  enriched_catalogs = {
    for cat_name, cat in local.catalog_map : cat_name => merge(cat, {
      # 1. Calculate Catalog Storage Root (S3)
      calculated_storage_root = cat.type == "MANAGED" ? (
        lookup(cat, "storage_root", null) != null ?
        "s3://${var.bucket_name}/${trim(cat.storage_root, "/")}/${var.deployment_id_aws}/" :
        "s3://${var.bucket_name}/${trim(var.managed_storage_root, "/")}/${var.deployment_id_aws}/"
      ) : null

      # 2. Calculate Volume Storage Locations (S3)
      schemas = [
        for s in lookup(cat, "schemas", []) : merge(s, {
          volumes = [
            for v in lookup(s, "volumes", []) : merge(v, {
              calculated_storage_location = lookup(v, "volume_type", "MANAGED") == "EXTERNAL" ? (
                "s3://${var.bucket_name}/${trim(v.location_path, "/")}/${var.deployment_id_aws}/${trim(v.volume_path, "/")}/"
              ) : null
            })
          ]
        })
      ]
    })
  }
}



### 1. External Locations Module (AWS)
module "external_locations" {
  source   = "../../../../databricks/modules/global/external_location"
  for_each = local.loc_map

  # In AWS, the credential name refers to the Databricks Storage Credential linked to an IAM Role
  storage_credential_name = var.storage_credential_name
  location_name           = each.value.unique_name
  calculated_url          = each.value.calculated_url

  external_location_grants = [
    for grant in local.ext_loc_grants_data : grant
    if grant.location_name == each.key
  ]

  providers = {
    databricks = databricks.uc_mws
  }
  depends_on = [time_sleep.iam_propagation]
}

### 2. AWS Managed Catalog Module
module "aws_catalog" {
  source = "../../../../databricks/modules/global/catalog"
  # Using the enriched map to provide computed S3 paths
  for_each = local.enriched_catalogs

  catalog              = each.value
  managed_storage_root = var.managed_storage_root

  catalog_grants = [
    for g in local.catalog_grants_data : g
    if g.catalog_name == each.key
  ]

  managed_schema_grants = local.managed_schema_grants_data
  volume_grants         = local.volume_grants_data

  providers = {
    databricks = databricks.uc_mws
  }

  depends_on = [module.external_locations]
}