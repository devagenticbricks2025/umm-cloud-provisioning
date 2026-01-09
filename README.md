# UMM Cloud Provisioning

Automated Azure cloud resource provisioning via ServiceNow Service Catalog and GitHub Actions.

## Overview

This solution enables self-service cloud resource provisioning with:
- **Single unified form** in ServiceNow for all resource types
- **Manager approval workflow** before provisioning
- **Automated provisioning** via GitHub Actions and Terraform
- **Cost tracking** with mandatory tagging

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  ServiceNow  │───▶│   Manager    │───▶│   GitHub     │───▶│    Azure     │
│   Catalog    │    │   Approval   │    │   Actions    │    │   Resources  │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

## Supported Resources

| Resource | Description |
|----------|-------------|
| **Virtual Machine** | Ubuntu, Windows Server, or RHEL with configurable sizes |
| **Storage Account** | Blob storage with LRS/GRS/ZRS replication |
| **Databricks Workspace** | Standard or Premium tier (Premium required for PHI) |

## Quick Start

### Prerequisites

1. **Azure Subscription** - [Create free trial](https://azure.microsoft.com/free/)
2. **ServiceNow Instance** - [Request developer instance](https://developer.servicenow.com)
3. **GitHub Account** - With repository access

### Setup Steps

#### 1. Azure Configuration

```bash
# Login to Azure
az login

# Create Service Principal
az ad sp create-for-rbac \
  --name "github-actions-umm" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth > azure-credentials.json

# Create Terraform state storage
az group create --name rg-terraform-state --location eastus

az storage account create \
  --name ummtfstate<UNIQUE_SUFFIX> \
  --resource-group rg-terraform-state \
  --sku Standard_LRS

az storage container create \
  --name tfstate \
  --account-name ummtfstate<UNIQUE_SUFFIX>
```

#### 2. GitHub Configuration

Add these secrets to your repository (Settings → Secrets → Actions):

| Secret | Description |
|--------|-------------|
| `AZURE_CREDENTIALS` | Full JSON from service principal |
| `AZURE_CLIENT_ID` | Client ID from JSON |
| `AZURE_CLIENT_SECRET` | Client secret from JSON |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `AZURE_TENANT_ID` | Tenant ID |
| `TF_STATE_RG` | `rg-terraform-state` |
| `TF_STATE_STORAGE` | Your storage account name |
| `SERVICENOW_INSTANCE` | e.g., `dev12345` |
| `SERVICENOW_USER` | ServiceNow admin username |
| `SERVICENOW_PASSWORD` | ServiceNow admin password |

#### 3. ServiceNow Configuration

1. **Create Category**: Service Catalog → Catalog Definitions → Maintain Categories
   - Name: `Cloud Services`

2. **Create Catalog Item**: Service Catalog → Catalog Definitions → Maintain Items
   - Use configuration from `servicenow/catalog-item-config.json`

3. **Create Variables**: Add all variables from the config file

4. **Create UI Policies**: Configure dynamic field visibility

5. **Set System Properties**:
   - `x_umm_cloud.github_pat` - Your GitHub PAT
   - `x_umm_cloud.github_owner` - Your GitHub org/username
   - `x_umm_cloud.github_repo` - `umm-cloud-provisioning`

6. **Create Business Rule**: Use `servicenow/business-rule.js`

## Repository Structure

```
umm-cloud-provisioning/
├── .github/
│   └── workflows/
│       └── provision-azure-resource.yml  # Unified workflow
├── terraform/
│   └── modules/
│       ├── vm/                           # Virtual Machine module
│       │   └── main.tf
│       ├── storage/                      # Storage Account module
│       │   └── main.tf
│       └── databricks/                   # Databricks module
│           └── main.tf
├── servicenow/
│   ├── business-rule.js                  # Webhook trigger script
│   └── catalog-item-config.json          # Form configuration
└── README.md
```

## Demo Walkthrough

1. **Login** to ServiceNow as a regular user
2. **Navigate** to Service Catalog → Cloud Services
3. **Select** "Request Azure Cloud Resource"
4. **Fill form**:
   - Resource Type: `Virtual Machine`
   - Resource Name: `demo-vm-001`
   - Environment: `Development`
   - Cost Center: `CC-DEMO-001`
   - Justification: `Demo for RFP presentation`
   - VM Size: `Standard_D2s_v3`
   - OS: `Ubuntu 22.04 LTS`
5. **Submit** request
6. **Approve** as manager (or use admin)
7. **Monitor** GitHub Actions workflow
8. **Verify** resource creation in Azure Portal
9. **Check** ServiceNow ticket for completion details

## Manual Workflow Testing

You can test the workflow without ServiceNow:

```bash
# Via GitHub CLI
gh workflow run provision-azure-resource.yml \
  -f ticket_number=RITM0010001 \
  -f resource_type=vm \
  -f resource_name=testvm001 \
  -f environment=dev \
  -f cost_center=CC-TEST-001

# Or use the GitHub UI:
# Actions → Provision Azure Resource → Run workflow
```

## Resource Tagging

All resources are tagged with:

| Tag | Description |
|-----|-------------|
| `Environment` | dev, staging, prod |
| `CostCenter` | For billing |
| `TicketNumber` | ServiceNow reference |
| `RequestedBy` | User email |
| `ManagedBy` | Terraform |
| `Project` | UMM-Cloud-Catalog |
| `ResourceType` | VM, Storage, Databricks |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| GitHub webhook 401 | Verify PAT has `repo` scope |
| GitHub webhook 404 | Check owner/repo names |
| Terraform init fails | Verify storage account access |
| VM quota exceeded | Request quota increase in Azure |
| ServiceNow connection fails | Check instance URL and credentials |

## Security Notes

- GitHub PAT should have minimal `repo` scope
- ServiceNow credentials should use a service account
- Azure Service Principal has Contributor role (can be scoped down)
- All secrets stored in GitHub Secrets (encrypted)

## Cost Estimates

| Resource | Size | Est. Monthly |
|----------|------|--------------|
| VM | Standard_D2s_v3 | ~$70 |
| VM | Standard_D4s_v3 | ~$140 |
| Storage | Standard LRS | ~$0.02/GB |
| Databricks | Standard | ~$0.40/DBU |

## License

Internal use only - University of Michigan Michigan Medicine

## Support

For issues or questions:
- Create a GitHub issue
- Contact the Cloud Team
