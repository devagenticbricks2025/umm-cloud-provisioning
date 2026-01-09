# terraform/modules/vm/main.tf
# Azure Virtual Machine Module for UMM Cloud Service Catalog

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ============================================
# Variables
# ============================================

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"

  validation {
    condition     = length(var.vm_name) >= 1 && length(var.vm_name) <= 64
    error_message = "VM name must be between 1 and 64 characters."
  }
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Size of the VM"

  validation {
    condition     = contains(["Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3", "Standard_B2s", "Standard_B4ms"], var.vm_size)
    error_message = "VM size must be one of: Standard_D2s_v3, Standard_D4s_v3, Standard_D8s_v3, Standard_B2s, Standard_B4ms."
  }
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

variable "requested_by" {
  type        = string
  default     = "unknown"
  description = "Email of requester"
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

  tags = {
    Environment     = var.environment
    CostCenter      = var.cost_center
    TicketNumber    = var.ticket_number
    RequestedBy     = var.requested_by
    ManagedBy       = "Terraform"
    Project         = "UMM-Cloud-Catalog"
    ResourceType    = "VirtualMachine"
    OperatingSystem = var.os_type
  }
}

# ============================================
# Resource Group
# ============================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.vm_name}-${var.environment}"
  location = var.location
  tags     = local.tags
}

# ============================================
# Networking Resources
# ============================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.vm_name}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_subnet" "main" {
  name                 = "subnet-${var.vm_name}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

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
      source_address_prefix      = "*"
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
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_public_ip" "main" {
  name                = "pip-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "main" {
  name                = "nic-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
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
# Virtual Machines
# ============================================

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  count               = local.selected_os.is_linux ? 1 : 0
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "azureadmin"
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    name                 = "osdisk-${var.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
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

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  count               = local.selected_os.is_linux ? 0 : 1
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "azureadmin"
  admin_password      = random_password.admin[0].result
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.main.id]

  os_disk {
    name                 = "osdisk-${var.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
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

# ============================================
# Outputs
# ============================================

output "resource_id" {
  description = "The ID of the virtual machine"
  value       = local.selected_os.is_linux ? azurerm_linux_virtual_machine.main[0].id : azurerm_windows_virtual_machine.main[0].id
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "public_ip" {
  description = "The public IP address of the virtual machine"
  value       = azurerm_public_ip.main.ip_address
}

output "private_ip" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_network_interface.main.private_ip_address
}

output "admin_username" {
  description = "The admin username for the virtual machine"
  value       = "azureadmin"
}

output "admin_password" {
  description = "The admin password for Windows VMs (sensitive)"
  value       = local.selected_os.is_linux ? "N/A - Use SSH key" : random_password.admin[0].result
  sensitive   = true
}

output "ssh_private_key" {
  description = "The SSH private key for Linux VMs (sensitive)"
  value       = local.selected_os.is_linux ? tls_private_key.ssh[0].private_key_pem : "N/A - Windows VM"
  sensitive   = true
}

output "os_type" {
  description = "The operating system type"
  value       = var.os_type
}

output "connection_instructions" {
  description = "Instructions for connecting to the VM"
  value       = local.selected_os.is_linux ? "SSH: ssh azureadmin@${azurerm_public_ip.main.ip_address}" : "RDP: Connect to ${azurerm_public_ip.main.ip_address} with username 'azureadmin'"
}
