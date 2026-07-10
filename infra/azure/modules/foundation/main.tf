# Azure foundation — the resources every other Azure layer depends on.
#
# Mirrors infra/aws/modules/foundation: a thin composition over the `_components`,
# with the private-mode gate expressed once, here, rather than inside each part.
# Nothing in the foundation is private-mode dependent — a resource group, a
# storage account and a key vault cost effectively nothing and are needed either
# way — so there is no gate in this layer.

resource "random_id" "kv_suffix" {
  byte_length = 3
}

resource "random_id" "adls_suffix" {
  byte_length = 4
}

locals {
  # Key Vault names are globally unique DNS names AND are soft-deleted for 90 days
  # on destroy. A stable name would therefore block the next deploy for three
  # months unless the vault is purged first. ADR-0013 keeps names stable except
  # where global uniqueness forces a suffix (buckets, SQL servers) — this is that
  # case, and the soft-delete window makes it not merely nice but necessary.
  key_vault_name = "${var.prefix_key_vault_name}-${var.environment}-${random_id.kv_suffix.hex}"

  # Storage account names are globally unique DNS labels, lowercase alphanumeric,
  # 3-24 chars. "adls" is unsurprisingly already taken by someone. 4 + 8 = 12.
  adls_name = "${var.adls_name}${random_id.adls_suffix.hex}"
}

module "resource_group" {
  source      = "./resource_group"
  environment = var.environment
  location    = var.location
}

module "adls_account" {
  source                  = "./adls_account"
  adls_name               = local.adls_name
  azure_containers        = var.azure_containers
  resource_group_name     = module.resource_group.resource_group_name
  resource_group_location = var.location
}

module "key_vault" {
  source                 = "./key_vault"
  key_vault_name         = local.key_vault_name
  location               = var.location
  resource_group_name    = module.resource_group.resource_group_name
  object_id              = var.admin_object_id
  orchestrator_object_id = var.orchestrator_object_id
}
