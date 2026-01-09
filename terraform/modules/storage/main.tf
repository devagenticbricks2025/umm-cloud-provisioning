# terraform/modules/storage/main.tf
# Azure Storage Account Module for UMM Cloud Service Catalog

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

variable "storage_name" {
  type        = string
  description = "Name of the storage account (must be globally unique, lowercase, 3-24 chars)"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "storage_tier" {
  type        = string
  default     = "Standard"
  description = "Storage tier: Standard or Premium"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_tier)
    error_message = "Storage tier must be either Standard or Premium."
  }
}

variable "replication" {
  type        = string
  default     = "LRS"
  description = "Replication type: LRS, GRS, ZRS"

  validation {
    condition     = contains(["LRS", "GRS", "ZRS", "RAGRS"], var.replication)
    error_message = "Replication must be one of: LRS, GRS, ZRS, RAGRS."
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

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

# ============================================
# Local Values
# ============================================

locals {
  tags = {
    Environment  = var.environment
    CostCenter   = var.cost_center
    TicketNumber = var.ticket_number
    ManagedBy    = "Terraform"
    Project      = "UMM-Cloud-Catalog"
    ResourceType = "StorageAccount"
    StorageTier  = var.storage_tier
    Replication  = var.replication
  }
}

# ============================================
# Resource Group
# ============================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.storage_name}-${var.environment}"
  location = var.location
  tags     = local.tags
}

# ============================================
# Storage Account
# ============================================

resource "azurerm_storage_account" "main" {
  name                     = var.storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_tier
  account_replication_type = var.replication

  # Security settings
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  # Blob properties
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  # Network rules (default allow all - can be restricted)
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# ============================================
# Default Containers
# ============================================

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ============================================
# Outputs
# ============================================

output "storage_account_id" {
  description = "The ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "primary_blob_endpoint" {
  description = "The primary blob endpoint URL"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_file_endpoint" {
  description = "The primary file endpoint URL"
  value       = azurerm_storage_account.main.primary_file_endpoint
}

output "primary_access_key" {
  description = "The primary access key (sensitive)"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "The primary connection string (sensitive)"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "containers" {
  description = "List of created containers"
  value       = ["data", "uploads", "backups"]
}

output "storage_tier" {
  description = "The storage tier"
  value       = var.storage_tier
}

output "replication_type" {
  description = "The replication type"
  value       = var.replication
}
