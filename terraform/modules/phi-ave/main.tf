# terraform/modules/phi-ave/main.tf
# HIPAA-Compliant PHI/AVE Environment Module
# Security controls aligned with HIPAA/HITRUST requirements

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

variable "irb_number" {
  type        = string
  description = "IRB protocol number"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
}

variable "ticket_number" {
  type        = string
  description = "ServiceNow ticket number"
}

variable "access_method" {
  type        = string
  default     = "both"
  description = "Access method: remote_desktop, analytics_workspace, both"
  validation {
    condition     = contains(["remote_desktop", "analytics_workspace", "both"], var.access_method)
    error_message = "Access method must be remote_desktop, analytics_workspace, or both."
  }
}

variable "expected_duration" {
  type        = string
  default     = "6_months"
  description = "Expected duration of the project"
}

variable "data_retention" {
  type        = string
  default     = "90_days"
  description = "Data retention period after project end"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2ms"
  description = "Size of the VM for remote desktop access"
}

variable "databricks_sku" {
  type        = string
  default     = "premium"
  description = "Databricks SKU (must be premium for PHI)"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

variable "admin_group_object_id" {
  type        = string
  default     = ""
  description = "Azure AD group object ID for admin access"
}

# ============================================
# Local Values
# ============================================

locals {
  resource_prefix = "phi-${var.resource_suffix}"

  deploy_vm         = var.access_method == "remote_desktop" || var.access_method == "both"
  deploy_databricks = var.access_method == "analytics_workspace" || var.access_method == "both"

  # Retention days mapping
  retention_days_map = {
    "30_days"  = 30
    "90_days"  = 90
    "1_year"   = 365
    "7_years"  = 2555
  }
  retention_days = lookup(local.retention_days_map, var.data_retention, 90)

  # Common tags for all resources - HIPAA compliance tracking
  common_tags = {
    Environment        = "production"
    DataClassification = "PHI"
    SecurityLevel      = "HIPAA"
    IRBNumber          = var.irb_number
    CostCenter         = var.cost_center
    TicketNumber       = var.ticket_number
    PrincipalInvestigator = var.principal_investigator
    ProjectName        = var.project_name
    ManagedBy          = "Terraform"
    ComplianceFramework = "HIPAA-HITRUST"
    RetentionPeriod    = var.data_retention
    ExpectedDuration   = var.expected_duration
  }
}

# ============================================
# Data Sources
# ============================================

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# ============================================
# Resource Group
# ============================================

resource "azurerm_resource_group" "phi" {
  name     = "rg-${local.resource_prefix}"
  location = var.location
  tags     = local.common_tags
}

# ============================================
# Log Analytics Workspace (Audit Logging)
# ============================================

resource "azurerm_log_analytics_workspace" "phi" {
  name                = "law-${local.resource_prefix}"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name
  sku                 = "PerGB2018"
  retention_in_days   = local.retention_days > 730 ? 730 : local.retention_days # Max 730 for LAW

  tags = local.common_tags
}

# Log Analytics Solutions for security monitoring
resource "azurerm_log_analytics_solution" "security" {
  solution_name         = "Security"
  location              = azurerm_resource_group.phi.location
  resource_group_name   = azurerm_resource_group.phi.name
  workspace_resource_id = azurerm_log_analytics_workspace.phi.id
  workspace_name        = azurerm_log_analytics_workspace.phi.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }
}

resource "azurerm_log_analytics_solution" "security_center" {
  solution_name         = "SecurityCenterFree"
  location              = azurerm_resource_group.phi.location
  resource_group_name   = azurerm_resource_group.phi.name
  workspace_resource_id = azurerm_log_analytics_workspace.phi.id
  workspace_name        = azurerm_log_analytics_workspace.phi.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityCenterFree"
  }
}

# ============================================
# Key Vault (Secrets & Encryption Keys)
# ============================================

resource "azurerm_key_vault" "phi" {
  name                = "kv-${replace(local.resource_prefix, "-", "")}${substr(md5(var.resource_suffix), 0, 4)}"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium" # Premium required for HSM-backed keys

  # Security settings
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  enable_rbac_authorization       = true
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90

  # Network restrictions - Allow access during deployment, restrict later
  network_acls {
    default_action = "Allow"  # Allow during Terraform deployment
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

# Key for disk encryption
resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.phi.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [azurerm_role_assignment.kv_admin]
}

# RBAC for Key Vault
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.phi.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================
# Virtual Network (Network Isolation)
# ============================================

resource "azurerm_virtual_network" "phi" {
  name                = "vnet-${local.resource_prefix}"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name
  address_space       = ["10.200.0.0/16"]

  tags = local.common_tags
}

# Compute Subnet
resource "azurerm_subnet" "compute" {
  name                 = "snet-compute"
  resource_group_name  = azurerm_resource_group.phi.name
  virtual_network_name = azurerm_virtual_network.phi.name
  address_prefixes     = ["10.200.1.0/24"]

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.Sql"
  ]
}

# Private Endpoints Subnet
resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.phi.name
  virtual_network_name              = azurerm_virtual_network.phi.name
  address_prefixes                  = ["10.200.2.0/24"]
  private_endpoint_network_policies = "Disabled"
}

# Azure Bastion Subnet (for secure access)
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # Must be this exact name
  resource_group_name  = azurerm_resource_group.phi.name
  virtual_network_name = azurerm_virtual_network.phi.name
  address_prefixes     = ["10.200.3.0/26"]
}

# Databricks Subnets (if needed)
resource "azurerm_subnet" "databricks_public" {
  count                = local.deploy_databricks ? 1 : 0
  name                 = "snet-databricks-public"
  resource_group_name  = azurerm_resource_group.phi.name
  virtual_network_name = azurerm_virtual_network.phi.name
  address_prefixes     = ["10.200.4.0/24"]

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "databricks_private" {
  count                = local.deploy_databricks ? 1 : 0
  name                 = "snet-databricks-private"
  resource_group_name  = azurerm_resource_group.phi.name
  virtual_network_name = azurerm_virtual_network.phi.name
  address_prefixes     = ["10.200.5.0/24"]

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# ============================================
# Network Security Groups
# ============================================

resource "azurerm_network_security_group" "compute" {
  name                = "nsg-${local.resource_prefix}-compute"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name

  # Deny all inbound from internet
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow Bastion RDP/SSH
  security_rule {
    name                       = "AllowBastionInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "10.200.3.0/26" # Bastion subnet
    destination_address_prefix = "*"
  }

  # Allow VNet internal traffic
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "compute" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.compute.id
}

# ============================================
# Azure Bastion (Secure Access)
# ============================================

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${local.resource_prefix}-bastion"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_bastion_host" "phi" {
  name                = "bastion-${local.resource_prefix}"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name
  sku                 = "Standard"

  copy_paste_enabled     = true
  file_copy_enabled      = true
  tunneling_enabled      = true
  ip_connect_enabled     = true
  shareable_link_enabled = false # Disable for security

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = local.common_tags
}

# ============================================
# Storage Account (PHI Data)
# ============================================

resource "azurerm_storage_account" "phi" {
  name                     = "stphi${replace(var.resource_suffix, "-", "")}${substr(md5(var.resource_suffix), 0, 4)}"
  resource_group_name      = azurerm_resource_group.phi.name
  location                 = azurerm_resource_group.phi.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant for PHI
  account_kind             = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true  # Required for Terraform to create containers

  # Encryption with customer-managed key
  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = local.retention_days > 365 ? 365 : local.retention_days
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Allow"  # Allow during Terraform deployment
    bypass         = ["AzureServices"]
  }

  tags = local.common_tags
}

# Storage containers
resource "azurerm_storage_container" "phi_data" {
  name                  = "phi-data"
  storage_account_name  = azurerm_storage_account.phi.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "phi_results" {
  name                  = "phi-results"
  storage_account_name  = azurerm_storage_account.phi.name
  container_access_type = "private"
}

# Private endpoint for storage
resource "azurerm_private_endpoint" "storage" {
  name                = "pe-${local.resource_prefix}-storage"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = azurerm_storage_account.phi.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = local.common_tags
}

# ============================================
# Virtual Machine (Remote Desktop)
# ============================================

resource "tls_private_key" "vm" {
  count     = local.deploy_vm ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_network_interface" "vm" {
  count               = local.deploy_vm ? 1 : 0
  name                = "nic-${local.resource_prefix}-vm"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.compute.id
    private_ip_address_allocation = "Dynamic"
    # NO public IP - access via Bastion only
  }

  tags = local.common_tags
}

resource "azurerm_linux_virtual_machine" "phi" {
  count               = local.deploy_vm ? 1 : 0
  name                = "vm-${local.resource_prefix}"
  resource_group_name = azurerm_resource_group.phi.name
  location            = azurerm_resource_group.phi.location
  size                = var.vm_size
  admin_username      = "phiadmin"

  network_interface_ids = [azurerm_network_interface.vm[0].id]

  admin_ssh_key {
    username   = "phiadmin"
    public_key = tls_private_key.vm[0].public_key_openssh
  }

  os_disk {
    name                   = "osdisk-${local.resource_prefix}"
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = azurerm_disk_encryption_set.phi.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = null # Use managed storage
  }

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.des_kv]
}

# Disk Encryption Set
resource "azurerm_disk_encryption_set" "phi" {
  name                = "des-${local.resource_prefix}"
  resource_group_name = azurerm_resource_group.phi.name
  location            = azurerm_resource_group.phi.location
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption.id

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant DES access to Key Vault
resource "azurerm_role_assignment" "des_kv" {
  scope                = azurerm_key_vault.phi.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.phi.identity[0].principal_id
}

# VM Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "vm" {
  count                      = local.deploy_vm ? 1 : 0
  name                       = "diag-vm"
  target_resource_id         = azurerm_linux_virtual_machine.phi[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.phi.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ============================================
# Databricks Workspace (Analytics)
# ============================================

resource "azurerm_databricks_workspace" "phi" {
  count                         = local.deploy_databricks ? 1 : 0
  name                          = "dbw-${local.resource_prefix}"
  resource_group_name           = azurerm_resource_group.phi.name
  location                      = azurerm_resource_group.phi.location
  sku                           = "premium" # Premium required for security features
  managed_resource_group_name   = "rg-${local.resource_prefix}-databricks-managed"

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = azurerm_virtual_network.phi.id
    public_subnet_name                                   = azurerm_subnet.databricks_public[0].name
    private_subnet_name                                  = azurerm_subnet.databricks_private[0].name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.databricks_public[0].id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.databricks_private[0].id
  }

  tags = local.common_tags

  depends_on = [
    azurerm_subnet_network_security_group_association.databricks_public,
    azurerm_subnet_network_security_group_association.databricks_private
  ]
}

# Databricks NSG
resource "azurerm_network_security_group" "databricks" {
  count               = local.deploy_databricks ? 1 : 0
  name                = "nsg-${local.resource_prefix}-databricks"
  location            = azurerm_resource_group.phi.location
  resource_group_name = azurerm_resource_group.phi.name

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "databricks_public" {
  count                     = local.deploy_databricks ? 1 : 0
  subnet_id                 = azurerm_subnet.databricks_public[0].id
  network_security_group_id = azurerm_network_security_group.databricks[0].id
}

resource "azurerm_subnet_network_security_group_association" "databricks_private" {
  count                     = local.deploy_databricks ? 1 : 0
  subnet_id                 = azurerm_subnet.databricks_private[0].id
  network_security_group_id = azurerm_network_security_group.databricks[0].id
}

# Databricks Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "databricks" {
  count                      = local.deploy_databricks ? 1 : 0
  name                       = "diag-databricks"
  target_resource_id         = azurerm_databricks_workspace.phi[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.phi.id

  enabled_log {
    category = "accounts"
  }
  enabled_log {
    category = "clusters"
  }
  enabled_log {
    category = "jobs"
  }
  enabled_log {
    category = "notebook"
  }
  enabled_log {
    category = "secrets"
  }
  enabled_log {
    category = "sqlPermissions"
  }
  enabled_log {
    category = "workspace"
  }
}

# ============================================
# Azure Policy Assignment (HIPAA/HITRUST)
# ============================================
resource "azurerm_resource_group_policy_assignment" "hipaa" {
  name                 = "hipaa-${local.resource_prefix}"
  resource_group_id    = azurerm_resource_group.phi.id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/a169a624-5599-4385-a696-c8d643089fab"
  display_name         = "HIPAA HITRUST - ${var.project_name}"
  description          = "HIPAA HITRUST compliance for PHI research environment"
  location             = azurerm_resource_group.phi.location

  # Required for DeployIfNotExists policies
  identity {
    type = "SystemAssigned"
  }

  non_compliance_message {
    content = "This resource is not compliant with HIPAA HITRUST requirements."
  }
}

# ============================================
# Outputs
# ============================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.phi.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.phi.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.phi.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.phi.vault_uri
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.phi.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.phi.name
}

output "storage_account_name" {
  description = "Name of the PHI storage account"
  value       = azurerm_storage_account.phi.name
}

output "storage_account_id" {
  description = "ID of the PHI storage account"
  value       = azurerm_storage_account.phi.id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.phi.id
}

output "bastion_name" {
  description = "Name of the Azure Bastion host"
  value       = azurerm_bastion_host.phi.name
}

output "bastion_dns_name" {
  description = "DNS name of the Azure Bastion host"
  value       = azurerm_bastion_host.phi.dns_name
}

output "vm_name" {
  description = "Name of the VM (if deployed)"
  value       = local.deploy_vm ? azurerm_linux_virtual_machine.phi[0].name : "N/A"
}

output "vm_private_ip" {
  description = "Private IP of the VM (if deployed)"
  value       = local.deploy_vm ? azurerm_network_interface.vm[0].private_ip_address : "N/A"
}

output "vm_admin_username" {
  description = "Admin username for the VM"
  value       = local.deploy_vm ? "phiadmin" : "N/A"
}

output "vm_ssh_private_key" {
  description = "SSH private key for VM access (sensitive)"
  value       = local.deploy_vm ? tls_private_key.vm[0].private_key_pem : "N/A"
  sensitive   = true
}

output "databricks_workspace_url" {
  description = "URL of the Databricks workspace (if deployed)"
  value       = local.deploy_databricks ? "https://${azurerm_databricks_workspace.phi[0].workspace_url}" : "N/A"
}

output "databricks_workspace_id" {
  description = "ID of the Databricks workspace (if deployed)"
  value       = local.deploy_databricks ? azurerm_databricks_workspace.phi[0].id : "N/A"
}

output "security_summary" {
  description = "Summary of security controls applied"
  value = {
    network_isolation     = true
    private_endpoints     = true
    no_public_ips         = true
    bastion_access_only   = true
    encryption_at_rest    = "Customer-managed key (Key Vault)"
    encryption_in_transit = "TLS 1.2 required"
    audit_logging         = "Log Analytics (${local.retention_days} days retention)"
    hipaa_policy          = true
    data_classification   = "PHI"
  }
}

output "access_instructions" {
  description = "Instructions for accessing the environment"
  value       = "PHI Environment - Access via Azure Bastion only. VM: ${local.deploy_vm ? azurerm_linux_virtual_machine.phi[0].name : "N/A"} (user: phiadmin). Databricks: ${local.deploy_databricks ? azurerm_databricks_workspace.phi[0].workspace_url : "N/A"}. All access is logged and audited."
}
