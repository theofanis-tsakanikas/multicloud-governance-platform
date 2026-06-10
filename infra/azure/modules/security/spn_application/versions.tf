terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.56.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.7.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "0.2.0"
    }
  }
}