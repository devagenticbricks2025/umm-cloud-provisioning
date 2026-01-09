# terraform/modules/databricks/main.tf
# Azure Databricks Workspace Module for UMM Cloud Service Catalog

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# ============================================
# Variables
# ============================================

variable "workspace_name" {
  type        = string
  description = "Name of the Databricks workspace"

  validation {
    condition     = length(var.workspace_name) >= 3 && length(var.workspace_name) <= 64
    error_message = "Workspace name must be between 3 and 64 characters."
  }
}

variable "pricing_tier" {
  type        = string
  default     = "standard"
  description = "Pricing tier: standard or premium"

  validation {
    condition     = contains(["standard", "premium"], var.pricing_tier)
    error_message = "Pricing tier must be either standard or premium."
  }
}

variable "environment" {
  type        = string
  description = "Environment: dev, staging, prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
}

variable "ticket_number" {
  type        = string
  description = "ServiceNow ticket number"
}

variable "data_classification" {
  type        = string
  default     = "internal"
  description = "Data classification: public, internal, confidential, phi"

  validation {
    condition     = contains(["public", "internal", "confidential", "phi"], var.data_classification)
    error_message = "Data classification must be one of: public, internal, confidential, phi."
  }
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

# ============================================
# Local Values
# ============================================

locals {
  # Require premium tier for PHI data
  effective_pricing_tier = var.data_classification == "phi" ? "premium" : var.pricing_tier

  tags = {
    Environment        = var.environment
    CostCenter         = var.cost_center
    TicketNumber       = var.ticket_number
    DataClassification = var.data_classification
    ManagedBy          = "Terraform"
    Project            = "UMM-Cloud-Catalog"
    ResourceType       = "DatabricksWorkspace"
    PricingTier        = local.effective_pricing_tier
  }

  # HIPAA compliance note for PHI data
  is_hipaa_required = var.data_classification == "phi"
}

# ============================================
# Resource Group
# ============================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.workspace_name}-${var.environment}"
  location = var.location
  tags     = local.tags
}

# ============================================
# Databricks Workspace
# ============================================

resource "azurerm_databricks_workspace" "main" {
  name                        = var.workspace_name
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  sku                         = local.effective_pricing_tier
  managed_resource_group_name = "rg-${var.workspace_name}-databricks-managed"

  # Enable features for premium tier
  dynamic "custom_parameters" {
    for_each = local.effective_pricing_tier == "premium" ? [1] : []
    content {
      no_public_ip = false
    }
  }

  tags = local.tags
}

# ============================================
# Outputs
# ============================================

output "workspace_id" {
  description = "The ID of the Databricks workspace"
  value       = azurerm_databricks_workspace.main.id
}

output "workspace_url" {
  description = "The URL of the Databricks workspace"
  value       = azurerm_databricks_workspace.main.workspace_url
}

output "workspace_name" {
  description = "The name of the Databricks workspace"
  value       = azurerm_databricks_workspace.main.name
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "managed_resource_group_name" {
  description = "The name of the managed resource group"
  value       = azurerm_databricks_workspace.main.managed_resource_group_name
}

output "pricing_tier" {
  description = "The pricing tier of the workspace"
  value       = local.effective_pricing_tier
}

output "data_classification" {
  description = "The data classification"
  value       = var.data_classification
}

output "is_hipaa_compliant" {
  description = "Whether the workspace is configured for HIPAA compliance"
  value       = local.is_hipaa_required
}

output "access_url" {
  description = "Full URL to access the Databricks workspace"
  value       = "https://${azurerm_databricks_workspace.main.workspace_url}"
}
