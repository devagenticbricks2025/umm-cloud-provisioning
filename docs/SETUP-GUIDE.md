# Setup Guide - ServiceNow to Azure Integration

This guide walks you through setting up the complete integration step-by-step.

## Table of Contents
1. [Azure Setup](#1-azure-setup)
2. [GitHub Setup](#2-github-setup)
3. [ServiceNow Setup](#3-servicenow-setup)
4. [Testing](#4-testing)

---

## 1. Azure Setup

### 1.1 Create Azure Free Trial (if needed)

1. Go to https://azure.microsoft.com/free/
2. Click "Start free"
3. Sign in with Microsoft account
4. Complete verification (credit card required, not charged)
5. You get **$200 credit for 30 days**

### 1.2 Create Service Principal

Open Azure Cloud Shell or local terminal with Azure CLI:

```bash
# Login to Azure
az login

# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Create Service Principal with Contributor role
az ad sp create-for-rbac \
  --name "github-actions-umm-demo" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth
```

**SAVE THE OUTPUT** - you'll need this JSON for GitHub secrets:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  ...
}
```

### 1.3 Create Terraform State Storage

```bash
# Create resource group for Terraform state
az group create \
  --name rg-terraform-state \
  --location eastus

# Create storage account (name must be globally unique!)
# Replace <UNIQUE_SUFFIX> with random characters
STORAGE_NAME="ummtfstate$(openssl rand -hex 4)"
echo "Storage Account: $STORAGE_NAME"

az storage account create \
  --name $STORAGE_NAME \
  --resource-group rg-terraform-state \
  --location eastus \
  --sku Standard_LRS

# Create container for state files
az storage container create \
  --name tfstate \
  --account-name $STORAGE_NAME
```

**Note your storage account name** - you'll need it for GitHub secrets.

---

## 2. GitHub Setup

### 2.1 Create Repository

1. Go to GitHub and create new repository: `umm-cloud-provisioning`
2. Initialize with README (optional)
3. Clone locally:
   ```bash
   git clone https://github.com/YOUR-ORG/umm-cloud-provisioning.git
   cd umm-cloud-provisioning
   ```

### 2.2 Copy Files

Copy all files from this folder to your repository:
```
.github/workflows/provision-azure-resource.yml
terraform/modules/vm/main.tf
terraform/modules/storage/main.tf
terraform/modules/databricks/main.tf
servicenow/business-rule.js
servicenow/catalog-item-config.json
README.md
.gitignore
docs/SETUP-GUIDE.md
```

### 2.3 Configure GitHub Secrets

Go to: Repository → Settings → Secrets and variables → Actions → New repository secret

Add each secret:

| Secret Name | Value | Where to get it |
|-------------|-------|-----------------|
| `AZURE_CREDENTIALS` | Entire JSON output from service principal | Step 1.2 |
| `AZURE_CLIENT_ID` | `clientId` from JSON | Step 1.2 |
| `AZURE_CLIENT_SECRET` | `clientSecret` from JSON | Step 1.2 |
| `AZURE_SUBSCRIPTION_ID` | `subscriptionId` from JSON | Step 1.2 |
| `AZURE_TENANT_ID` | `tenantId` from JSON | Step 1.2 |
| `TF_STATE_RG` | `rg-terraform-state` | Step 1.3 |
| `TF_STATE_STORAGE` | Your storage account name | Step 1.3 |
| `SERVICENOW_INSTANCE` | Your instance name (e.g., `dev12345`) | Step 3.1 |
| `SERVICENOW_USER` | `admin` (or service account) | Step 3.1 |
| `SERVICENOW_PASSWORD` | Your admin password | Step 3.1 |

### 2.4 Create GitHub PAT (Personal Access Token)

1. Go to: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name: `ServiceNow-UMM-Integration`
4. Expiration: 90 days (or as needed)
5. Scopes: Check `repo` (full control of private repositories)
6. Click "Generate token"
7. **COPY AND SAVE THE TOKEN** - you'll need it for ServiceNow

### 2.5 Push to GitHub

```bash
git add .
git commit -m "Initial setup of UMM Cloud Provisioning"
git push origin main
```

---

## 3. ServiceNow Setup

### 3.1 Get ServiceNow Developer Instance

1. Go to https://developer.servicenow.com
2. Create account (free)
3. Click "Start Building"
4. Click "Request Instance"
5. Choose latest version (e.g., Washington DC)
6. Wait 10-15 minutes for provisioning
7. Note your instance URL: `https://devXXXXX.service-now.com`

### 3.2 Login and Navigate

1. Login to your instance as `admin`
2. Use the Application Navigator (left sidebar filter)

### 3.3 Create Category

1. Navigate: **Service Catalog → Catalog Definitions → Maintain Categories**
2. Click "New"
3. Fill in:
   - **Title**: `Cloud Services`
   - **Description**: `Pre-approved Azure cloud resource provisioning`
   - **Catalog**: `Service Catalog`
   - **Active**: `true`
4. Save

### 3.4 Create Catalog Item

1. Navigate: **Service Catalog → Catalog Definitions → Maintain Items**
2. Click "New"
3. Fill in:
   - **Name**: `Request Azure Cloud Resource`
   - **Catalogs**: `Service Catalog`
   - **Category**: `Cloud Services`
   - **Short description**: `Request Azure VM, Storage, or Databricks resources`
   - **Description**: See `catalog-item-config.json`
4. Save
5. Note the `sys_id` of this item (visible in URL)

### 3.5 Create Variables

For each variable in `catalog-item-config.json`, do:

1. Scroll down to "Variables" related list
2. Click "New"
3. Fill in the variable details:
   - **Name**: (e.g., `resource_type`)
   - **Question**: (e.g., `Resource Type`)
   - **Type**: (e.g., `Select Box`)
   - **Mandatory**: as specified
   - **Order**: as specified
4. For Select Box types, add choices in the "Question Choices" related list
5. Save each variable

**Variables to create:**
1. `resource_type` - Select Box (vm, storage, databricks)
2. `resource_name` - Single Line Text
3. `environment` - Select Box (dev, staging, prod)
4. `cost_center` - Single Line Text
5. `justification` - Multi Line Text
6. `vm_size` - Select Box
7. `os_type` - Select Box
8. `storage_tier` - Select Box
9. `replication` - Select Box
10. `pricing_tier` - Select Box
11. `data_classification` - Select Box

### 3.6 Create UI Policies

1. Navigate: **Service Catalog → Catalog Definitions → Catalog UI Policies**
2. Click "New"
3. Create each policy:

**Policy 1: Show VM Fields**
- **Catalog Item**: Request Azure Cloud Resource
- **Short description**: Show VM fields when VM is selected
- **Applies to**: Catalog Item
- **Applies on a Catalog Item view**: true
- **On load**: true
- **Reverse if false**: true
- Conditions: `resource_type` `is` `vm`
- Actions: Show `vm_size`, `os_type`; Hide others

**Policy 2: Show Storage Fields**
- Similar setup for storage fields

**Policy 3: Show Databricks Fields**
- Similar setup for Databricks fields

### 3.7 Set System Properties

1. Navigate: **System Properties → All Properties**
2. Create new properties:

| Name | Type | Value |
|------|------|-------|
| `x_umm_cloud.github_pat` | password | Your GitHub PAT from step 2.4 |
| `x_umm_cloud.github_owner` | string | Your GitHub org/username |
| `x_umm_cloud.github_repo` | string | `umm-cloud-provisioning` |

### 3.8 Create Business Rule

1. Navigate: **System Definition → Business Rules**
2. Click "New"
3. Fill in:
   - **Name**: `Trigger GitHub Actions After Approval`
   - **Table**: `Request Item [sc_req_item]`
   - **When**: `after`
   - **Update**: `true`
   - **Advanced**: `true`
4. Set condition:
   ```
   current.state == 3 && previous.state != 3 && current.cat_item.name == 'Request Azure Cloud Resource'
   ```
5. Paste script from `servicenow/business-rule.js`
6. Save

### 3.9 Configure Approval (Optional for Demo)

For demo purposes, you can skip approval. For production:

1. Navigate: **Workflow → Workflow Editor**
2. Create workflow for catalog item approval
3. Or use Flow Designer for simpler setup

---

## 4. Testing

### 4.1 Test GitHub Workflow Manually

1. Go to: Repository → Actions → Provision Azure Resource
2. Click "Run workflow"
3. Fill in test values:
   - ticket_number: `RITM0010001`
   - resource_type: `vm`
   - resource_name: `testvm001`
   - environment: `dev`
   - cost_center: `CC-TEST-001`
4. Click "Run workflow"
5. Monitor the workflow execution
6. Verify resource creation in Azure Portal

### 4.2 Test ServiceNow Integration

1. Login to ServiceNow as a regular user
2. Navigate to: Service Catalog → Cloud Services
3. Click "Request Azure Cloud Resource"
4. Fill in the form:
   - Resource Type: `Virtual Machine`
   - Resource Name: `demovm001`
   - Environment: `Development`
   - Cost Center: `CC-DEMO-001`
   - Justification: `Testing integration`
   - VM Size: `Standard_D2s_v3`
   - OS: `Ubuntu 22.04 LTS`
5. Submit

### 4.3 Approve Request

1. Login as manager/admin
2. Navigate to: Self-Service → My Approvals
3. Approve the request
4. Monitor GitHub Actions workflow
5. Check ticket work notes for status updates

### 4.4 Verify Resources

1. Login to Azure Portal
2. Navigate to Resource Groups
3. Find `rg-demovm001-dev`
4. Verify VM and associated resources
5. Check tags are applied correctly

---

## Cleanup

To delete test resources:

```bash
# Delete specific resource group
az group delete --name rg-demovm001-dev --yes --no-wait

# Or delete all UMM resources
az group list --query "[?contains(name, 'UMM-Cloud-Catalog')].name" -o tsv | \
  xargs -I {} az group delete --name {} --yes --no-wait
```

---

## Common Issues

### GitHub workflow not triggering
- Check business rule is active
- Verify PAT has `repo` scope
- Check System Properties are set correctly

### Terraform state errors
- Ensure storage account exists
- Verify TF_STATE_RG and TF_STATE_STORAGE secrets

### VM creation fails
- Check subscription quota
- Verify region availability

### ServiceNow not receiving updates
- Check SERVICENOW_* secrets
- Verify instance is active (PDIs hibernate after 10 days)

---

## Next Steps

1. Add more resource types (AKS, SQL Database, etc.)
2. Implement cost estimation before provisioning
3. Add self-service resource deletion workflow
4. Integrate with Azure Cost Management for reporting
