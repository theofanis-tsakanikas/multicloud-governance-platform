# 1. Creation of the Service Principal (SPN) at the Account Level
resource "databricks_service_principal" "automation_sp" {
  display_name = "dbx-${var.environment}-${var.spn_suffix}"
}

# Explicitly grant the Account Admin role to the SPN (Account Level)
resource "databricks_service_principal_role" "spn_metastore_admin" {
  service_principal_id = databricks_service_principal.automation_sp.id
  role                 = "account_admin"
}

# 2. Create Secret for SPN
resource "databricks_service_principal_secret" "sp_secret" {
  service_principal_id = databricks_service_principal.automation_sp.id
}



# 3. Store Credentials in the AWS Secret created in the previous module
resource "aws_secretsmanager_secret_version" "spn_creds_value" {
  secret_id = var.spn_secret_arn
  secret_string = jsonencode({
    spn_client_id     = databricks_service_principal.automation_sp.application_id
    spn_client_secret = databricks_service_principal_secret.sp_secret.secret
  })
}

# 4. Creation of the Admin Group
resource "databricks_group" "admins" {
  display_name = var.admin_group_name
}

# Grant the Admin Group MANAGE permission over the Service Principal
resource "databricks_access_control_rule_set" "spn_manage" {
  name = "accounts/${var.dbx_account_id}/servicePrincipals/${databricks_service_principal.automation_sp.application_id}/ruleSets/default"

  # Rule 1: Admins manage the SPN
  grant_rules {
    principals = ["groups/${databricks_group.admins.display_name}"]
    role       = "roles/servicePrincipal.manager"
  }

  # Rule 2: The SPN manages itself (Self-Manage)
  grant_rules {
    principals = ["servicePrincipals/${databricks_service_principal.automation_sp.application_id}"]
    role       = "roles/servicePrincipal.manager"
  }
}

# 5. Add Users to the Admin Group
resource "databricks_group_member" "admin_members" {
  for_each  = toset(var.metastore_admins)
  group_id  = databricks_group.admins.id
  member_id = each.key
}

# 6. Add the SPN to the Admin Group (so it inherits group permissions)
resource "databricks_group_member" "spn_admin_membership" {
  group_id  = databricks_group.admins.id
  member_id = databricks_service_principal.automation_sp.id
}

# Elevate the Admin Group to Account Admins
resource "databricks_group_role" "account_admin_group" {
  group_id = databricks_group.admins.id
  role     = "account_admin"
}

# 7. Creation of Functional Groups (from your input list)
resource "databricks_group" "functional_groups" {
  for_each     = toset(var.identity_groups)
  display_name = each.value
}