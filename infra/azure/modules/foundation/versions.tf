terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Pinned: the AWS modules pin exactly; Azure must too. adls_account uses 4.x-only syntax
      # (storage_account_id on the container), and lock files are gitignored, so an unpinned provider
      # would hand a fresh public clone whatever azurerm ships that day. ~> 4.0 = any 4.x, never 5.0.
      version = "~> 4.0"
    }
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
    random  = { source = "hashicorp/random", version = "~> 3.0" }
  }
}
