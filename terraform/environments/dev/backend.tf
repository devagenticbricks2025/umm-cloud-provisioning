# Backend configuration for Terraform state
# This file configures where Terraform stores its state

terraform {
  backend "azurerm" {
    # These values are set via -backend-config in CI/CD
    # resource_group_name  = "rg-terraform-state"
    # storage_account_name = "stterraformstate"
    # container_name       = "tfstate"
    # key                  = "research-computing.tfstate"
  }
}
