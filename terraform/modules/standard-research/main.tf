# terraform/modules/standard-research/main.tf
# Standard Research Computing Environment Module
# For non-PHI research workloads

# Note: This module is called from terraform/environments/*/main.tf
# Provider and backend configuration is in the root module

# ============================================
# Variables
# ============================================

variable "project_name" {
  type        = string
  description = "Name of the research project"
}

variable "resource_suffix" {
  type        = string
  description = "Unique suffix for resource names"
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

variable "ticket_number" {
  type        = string
  description = "ServiceNow ticket number"
}

variable "workload_types" {
  type        = string
  default     = "general"
  description = "Comma-separated workload types: statistical, imaging, ml, data_prep, recommend"
}

variable "expected_end_date" {
  type        = string
  default     = ""
  description = "Expected project end date"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D4s_v3"
  description = "Size of the VM"
}

variable "os_type" {
  type        = string
  default     = "ubuntu"
  description = "Operating system type: ubuntu, windows, rhel"

  validation {
    condition     = contains(["ubuntu", "windows", "rhel"], var.os_type)
    error_message = "OS type must be one of: ubuntu, windows, rhel."
  }
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment: dev, staging, prod"
}

# ============================================
# Local Values
# ============================================

locals {
  resource_prefix = "research-${var.resource_suffix}"

  # Workload-based VM sizing recommendations
  workload_list = split(",", var.workload_types)
  needs_gpu = contains(local.workload_list, "ml") || contains(local.workload_list, "imaging")

  # Recommended VM size based on workload
  recommended_vm_size = local.needs_gpu ? "Standard_NC6s_v3" : var.vm_size

  os_config = {
    ubuntu = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      is_linux  = true
    }
    windows = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-g2"
      is_linux  = false
    }
    rhel = {
      publisher = "RedHat"
      offer     = "RHEL"
      sku       = "8-lvm-gen2"
      is_linux  = true
    }
  }

  selected_os = local.os_config[var.os_type]

  # Common tags
  common_tags = {
    Environment           = var.environment
    DataClassification    = "Non-PHI"
    SecurityLevel         = "Standard"
    CostCenter            = var.cost_center
    TicketNumber          = var.ticket_number
    PrincipalInvestigator = var.principal_investigator
    ProjectName           = var.project_name
    Department            = var.department
    WorkloadTypes         = var.workload_types
    ExpectedEndDate       = var.expected_end_date
    ManagedBy             = "Terraform"
  }
}

# ============================================
# Data Sources
# ============================================

data "azurerm_client_config" "current" {}

# ============================================
# Resource Group
# ============================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_prefix}"
  location = var.location
  tags     = local.common_tags
}

# ============================================
# Networking Resources
# ============================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.resource_prefix}"
  address_space       = ["10.100.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "compute" {
  name                 = "snet-compute"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.100.1.0/24"]

  service_endpoints = [
    "Microsoft.Storage"
  ]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # SSH rule for Linux
  dynamic "security_rule" {
    for_each = local.selected_os.is_linux ? [1] : []
    content {
      name                       = "SSH"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"  # Consider restricting to UMich VPN
      destination_address_prefix = "*"
    }
  }

  # RDP rule for Windows
  dynamic "security_rule" {
    for_each = local.selected_os.is_linux ? [] : [1]
    content {
      name                       = "RDP"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "*"  # Consider restricting to UMich VPN
      destination_address_prefix = "*"
    }
  }

  # HTTPS outbound for package management
  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "compute" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "main" {
  name                = "pip-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "main" {
  name                = "nic-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.compute.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# ============================================
# Storage Account (Research Data)
# ============================================

resource "azurerm_storage_account" "main" {
  name                     = "stresearch${replace(var.resource_suffix, "-", "")}${substr(md5(var.resource_suffix), 0, 4)}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally redundant for non-PHI
  account_kind             = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.compute.id]
    ip_rules                   = []  # Add researcher IPs if needed
  }

  tags = local.common_tags
}

# Storage containers for research data
resource "azurerm_storage_container" "data" {
  name                  = "research-data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "results" {
  name                  = "research-results"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ============================================
# Credentials
# ============================================

# Random password for Windows VMs
resource "random_password" "admin" {
  count            = local.selected_os.is_linux ? 0 : 1
  length           = 20
  special          = true
  override_special = "!@#$%^&*"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# SSH key for Linux VMs
resource "tls_private_key" "ssh" {
  count     = local.selected_os.is_linux ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ============================================
# Virtual Machine
# ============================================

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  count               = local.selected_os.is_linux ? 1 : 0
  name                = "vm-${local.resource_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "researcher"
  tags                = local.common_tags

  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = "researcher"
    public_key = tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    name                 = "osdisk-${local.resource_prefix}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = local.selected_os.publisher
    offer     = local.selected_os.offer
    sku       = local.selected_os.sku
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  # Custom data for initial setup based on workload
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    # Research Computing Environment Setup
    apt-get update
    apt-get install -y python3 python3-pip git

    # Install packages based on workload type
    %{ if contains(local.workload_list, "statistical") }
    pip3 install pandas numpy scipy statsmodels
    apt-get install -y r-base
    %{ endif }

    %{ if contains(local.workload_list, "imaging") }
    pip3 install opencv-python pillow scikit-image
    %{ endif }

    %{ if contains(local.workload_list, "ml") }
    pip3 install scikit-learn tensorflow torch
    %{ endif }

    %{ if contains(local.workload_list, "data_prep") }
    pip3 install pandas numpy pyarrow
    %{ endif }

    # Create research directories
    mkdir -p /home/researcher/data
    mkdir -p /home/researcher/results
    mkdir -p /home/researcher/scripts
    chown -R researcher:researcher /home/researcher

    echo "Research computing environment ready"
    EOF
  )
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  count               = local.selected_os.is_linux ? 0 : 1
  name                = "vm-${local.resource_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "researcher"
  admin_password      = random_password.admin[0].result
  tags                = local.common_tags

  network_interface_ids = [azurerm_network_interface.main.id]

  os_disk {
    name                 = "osdisk-${local.resource_prefix}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = local.selected_os.publisher
    offer     = local.selected_os.offer
    sku       = local.selected_os.sku
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Grant VM access to storage account
resource "azurerm_role_assignment" "vm_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.selected_os.is_linux ? azurerm_linux_virtual_machine.main[0].identity[0].principal_id : azurerm_windows_virtual_machine.main[0].identity[0].principal_id
}

# ============================================
# Outputs
# ============================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = local.selected_os.is_linux ? azurerm_linux_virtual_machine.main[0].name : azurerm_windows_virtual_machine.main[0].name
}

output "vm_id" {
  description = "ID of the virtual machine"
  value       = local.selected_os.is_linux ? azurerm_linux_virtual_machine.main[0].id : azurerm_windows_virtual_machine.main[0].id
}

output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "admin_username" {
  description = "Admin username for the VM"
  value       = "researcher"
}

output "admin_password" {
  description = "Admin password for Windows VMs (sensitive)"
  value       = local.selected_os.is_linux ? "N/A - Use SSH key" : random_password.admin[0].result
  sensitive   = true
}

output "ssh_private_key" {
  description = "SSH private key for Linux VMs (sensitive)"
  value       = local.selected_os.is_linux ? tls_private_key.ssh[0].private_key_pem : "N/A - Windows VM"
  sensitive   = true
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "os_type" {
  description = "Operating system type"
  value       = var.os_type
}

output "workload_types" {
  description = "Workload types configured"
  value       = var.workload_types
}

output "connection_instructions" {
  description = "Instructions for connecting to the VM"
  value = local.selected_os.is_linux ? <<-EOT
    STANDARD RESEARCH COMPUTING - CONNECTION INSTRUCTIONS
    =====================================================

    1. SSH Connection:
       ssh researcher@${azurerm_public_ip.main.ip_address}

    2. Save the private key to a file and use:
       ssh -i private_key.pem researcher@${azurerm_public_ip.main.ip_address}

    3. Storage Account: ${azurerm_storage_account.main.name}
       - Use Azure Storage Explorer or azcopy
       - Containers: research-data, research-results, scripts

    Project: ${var.project_name}
    Department: ${var.department}
    Workloads: ${var.workload_types}
    Data Classification: Non-PHI
    EOT
  : <<-EOT
    STANDARD RESEARCH COMPUTING - CONNECTION INSTRUCTIONS
    =====================================================

    1. RDP Connection:
       Connect to ${azurerm_public_ip.main.ip_address}
       Username: researcher
       Password: (see Terraform outputs or ServiceNow ticket)

    2. Storage Account: ${azurerm_storage_account.main.name}
       - Use Azure Storage Explorer
       - Containers: research-data, research-results, scripts

    Project: ${var.project_name}
    Department: ${var.department}
    Workloads: ${var.workload_types}
    Data Classification: Non-PHI
    EOT
}

output "environment_summary" {
  description = "Summary of the environment"
  value = {
    project_name           = var.project_name
    department             = var.department
    principal_investigator = var.principal_investigator
    workload_types         = var.workload_types
    vm_size                = var.vm_size
    os_type                = var.os_type
    data_classification    = "Non-PHI"
    security_level         = "Standard"
    public_access          = true
    storage_replication    = "LRS"
  }
}
