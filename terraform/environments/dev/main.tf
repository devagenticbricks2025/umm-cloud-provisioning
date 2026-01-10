# terraform/environments/dev/main.tf
# Development environment configuration
# Used by GitHub Actions to provision research computing environments

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ============================================
# Variables (passed from GitHub Actions)
# ============================================

variable "request_type" {
  type        = string
  description = "Type of request: standard_research or phi_ave"
  default     = "standard_research"
}

variable "project_name" {
  type        = string
  description = "Name of the research project"
}

variable "resource_suffix" {
  type        = string
  description = "Unique suffix for resource naming"
}

variable "ticket_number" {
  type        = string
  description = "ServiceNow ticket number"
}

variable "principal_investigator" {
  type        = string
  description = "Email of the Principal Investigator"
}

variable "department" {
  type        = string
  default     = "other"
  description = "Department name"
}

variable "cost_center" {
  type        = string
  description = "Cost center/grant code for billing"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

# Standard Research variables
variable "workload_types" {
  type        = string
  default     = "general"
  description = "Comma-separated workload types"
}

variable "expected_end_date" {
  type        = string
  default     = ""
  description = "Expected project end date"
}

# PHI/AVE variables
variable "irb_number" {
  type        = string
  default     = ""
  description = "IRB protocol number (PHI only)"
}

variable "access_method" {
  type        = string
  default     = "both"
  description = "Access method: remote_desktop, analytics_workspace, both"
}

variable "expected_duration" {
  type        = string
  default     = "6_months"
  description = "Expected duration of the project"
}

variable "data_retention" {
  type        = string
  default     = "90_days"
  description = "Data retention period"
}

# ============================================
# Module Selection based on Request Type
# ============================================

module "standard_research" {
  source = "../../modules/standard-research"
  count  = var.request_type == "standard_research" ? 1 : 0

  project_name           = var.project_name
  resource_suffix        = var.resource_suffix
  principal_investigator = var.principal_investigator
  department             = var.department
  cost_center            = var.cost_center
  ticket_number          = var.ticket_number
  workload_types         = var.workload_types
  expected_end_date      = var.expected_end_date
  location               = var.location
  environment            = "dev"
}

module "phi_ave" {
  source = "../../modules/phi-ave"
  count  = var.request_type == "phi_ave" ? 1 : 0

  project_name           = var.project_name
  resource_suffix        = var.resource_suffix
  principal_investigator = var.principal_investigator
  irb_number             = var.irb_number
  cost_center            = var.cost_center
  ticket_number          = var.ticket_number
  access_method          = var.access_method
  expected_duration      = var.expected_duration
  data_retention         = var.data_retention
  location               = var.location
}

# ============================================
# Outputs
# ============================================

output "request_type" {
  description = "Type of environment provisioned"
  value       = var.request_type
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = var.request_type == "standard_research" ? module.standard_research[0].resource_group_name : module.phi_ave[0].resource_group_name
}

output "connection_info" {
  description = "Connection information"
  value = var.request_type == "standard_research" ? {
    type            = "Standard Research Computing"
    public_ip       = module.standard_research[0].public_ip
    admin_username  = module.standard_research[0].admin_username
    storage_account = module.standard_research[0].storage_account_name
    instructions    = module.standard_research[0].connection_instructions
  } : {
    type            = "PHI/AVE Secure Environment"
    bastion_name    = module.phi_ave[0].bastion_name
    vm_private_ip   = module.phi_ave[0].vm_private_ip
    admin_username  = module.phi_ave[0].vm_admin_username
    storage_account = module.phi_ave[0].storage_account_name
    instructions    = module.phi_ave[0].access_instructions
  }
}

output "security_summary" {
  description = "Security configuration summary"
  value = var.request_type == "phi_ave" ? module.phi_ave[0].security_summary : {
    network_isolation     = false
    private_endpoints     = false
    no_public_ips         = false
    bastion_access_only   = false
    encryption_at_rest    = "Platform-managed key"
    encryption_in_transit = "TLS 1.2"
    audit_logging         = "Basic"
    hipaa_policy          = false
    data_classification   = "Non-PHI"
  }
}

output "environment_summary" {
  description = "Complete environment summary"
  value = var.request_type == "standard_research" ? module.standard_research[0].environment_summary : {
    project_name           = var.project_name
    principal_investigator = var.principal_investigator
    irb_number             = var.irb_number
    access_method          = var.access_method
    duration               = var.expected_duration
    data_retention         = var.data_retention
    data_classification    = "PHI"
    security_level         = "HIPAA"
    public_access          = false
  }
}
