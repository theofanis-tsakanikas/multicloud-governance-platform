// 1. Role Assignment
// Adjusts the roles to the Service Principal (SPN)
// for all the scope of the ADLS Storage Account.
resource "azurerm_role_assignment" "az_ra_adls" {
  for_each             = toset(var.role_names)
  scope                = var.adls_account_id
  role_definition_name = each.value
  principal_id         = var.spn_object_id
} 