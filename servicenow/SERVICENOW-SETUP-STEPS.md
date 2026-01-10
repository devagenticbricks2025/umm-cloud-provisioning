# ServiceNow Setup Guide - Research Computing Services
## Step-by-Step Instructions for Full Wireframe Implementation

---

## Prerequisites
- ServiceNow Developer Instance (active)
- Admin access
- ~60 minutes for setup

---

## Part 1: Create Category

### Step 1.1: Navigate to Categories
1. In the Application Navigator, type: `Maintain Categories`
2. Click **Service Catalog > Catalog Definitions > Maintain Categories**

### Step 1.2: Create New Category
1. Click **New**
2. Fill in:
   - **Title**: `Research Computing Services`
   - **Description**: `Self-service research computing and PHI environments`
   - **Catalog**: Select `Service Catalog`
   - **Icon**: `fa-cloud` (or search for cloud icon)
   - **Active**: ✓ (checked)
3. Click **Submit**

---

## Part 2: Create Standard Research Computing Catalog Item

### Step 2.1: Create the Catalog Item
1. Navigate: **Service Catalog > Catalog Definitions > Maintain Items**
2. Click **New**
3. Fill in:
   - **Name**: `Start Research Computing`
   - **Catalogs**: Select `Service Catalog`
   - **Category**: Select `Research Computing Services`
   - **Short description**: `Simple compute and storage for research`
   - **Description**:
     ```
     Request computing resources for your research project.

     This is for non-PHI data only. If you need to work with Protected Health Information (PHI), please use 'Request Secure PHI Research (AVE)' instead.
     ```
   - **Icon**: `fa-desktop`
4. Click **Submit**
5. **Re-open** the item you just created (click on the name)

### Step 2.2: Create Variable Set - Step 1
1. Scroll down to **Variable Sets** related list
2. Click **New**
3. Fill in:
   - **Title**: `Step 1: About Your Research`
   - **Order**: `100`
   - **Display title**: ✓ (checked)
4. Click **Submit**

### Step 2.3: Create Variable Set - Step 2
1. Click **New** again
2. Fill in:
   - **Title**: `Step 2: Work Type`
   - **Order**: `200`
   - **Display title**: ✓ (checked)
3. Click **Submit**

### Step 2.4: Create Variable Set - Step 3
1. Click **New** again
2. Fill in:
   - **Title**: `Step 3: Review & Submit`
   - **Order**: `300`
   - **Display title**: ✓ (checked)
3. Click **Submit**

### Step 2.5: Create Variables

Go back to the Catalog Item and scroll to **Variables** related list.

**Variable 1: Project Name**
1. Click **New**
2. Fill in:
   - **Type**: `Single Line Text`
   - **Order**: `100`
   - **Question**: `Research Project Name`
   - **Name**: `project_name`
   - **Variable Set**: `Step 1: About Your Research`
   - **Mandatory**: ✓
   - **Help text**: `Enter a descriptive name for your research project`
3. Click **Submit**

**Variable 2: Department**
1. Click **New**
2. Fill in:
   - **Type**: `Select Box`
   - **Order**: `200`
   - **Question**: `Department`
   - **Name**: `department`
   - **Variable Set**: `Step 1: About Your Research`
   - **Mandatory**: ✓
3. Click **Submit**
4. Re-open this variable, scroll to **Question Choices**, add:
   - `internal_medicine` → `Internal Medicine`
   - `radiology` → `Radiology`
   - `cardiology` → `Cardiology`
   - `oncology` → `Oncology`
   - `neurology` → `Neurology`
   - `other` → `Other`

**Variable 3: Principal Investigator**
1. Click **New**
2. Fill in:
   - **Type**: `Reference`
   - **Order**: `300`
   - **Question**: `Principal Investigator`
   - **Name**: `principal_investigator`
   - **Variable Set**: `Step 1: About Your Research`
   - **Reference**: `User [sys_user]`
   - **Mandatory**: ✓
3. Click **Submit**

**Variable 4: Grant Code**
1. Click **New**
2. Fill in:
   - **Type**: `Single Line Text`
   - **Order**: `400`
   - **Question**: `Grant/Project Code`
   - **Name**: `grant_code`
   - **Variable Set**: `Step 1: About Your Research`
   - **Mandatory**: (unchecked)
3. Click **Submit**

**Variable 5: Requestor Role**
1. Click **New**
2. Fill in:
   - **Type**: `Select Box`
   - **Order**: `500`
   - **Question**: `Your Role`
   - **Name**: `requestor_role`
   - **Variable Set**: `Step 1: About Your Research`
   - **Mandatory**: ✓
   - **Default value**: `researcher`
3. Add choices: `researcher`, `analyst`, `lab_manager`, `student`

**Variable 6: End Date**
1. Click **New**
2. Fill in:
   - **Type**: `Date`
   - **Order**: `600`
   - **Question**: `Expected Project End Date`
   - **Name**: `expected_end_date`
   - **Variable Set**: `Step 1: About Your Research`
   - **Mandatory**: ✓
3. Click **Submit**

**Variable 7: Data Type**
1. Click **New**
2. Fill in:
   - **Type**: `Select Box`
   - **Order**: `100`
   - **Question**: `What type of data will you be working with?`
   - **Name**: `data_type`
   - **Variable Set**: `Step 2: Work Type`
   - **Mandatory**: ✓
   - **Default value**: `non_phi`
3. Add choices:
   - `non_phi` → `Non-PHI (No patient data)`
   - `phi` → `PHI - Use AVE Request Instead`

**Variables 8-12: Workload Checkboxes**
Create 5 checkbox variables:

| Order | Question | Name |
|-------|----------|------|
| 200 | Statistical Analysis | `workload_statistical` |
| 210 | Imaging Analysis | `workload_imaging` |
| 220 | Machine Learning / AI | `workload_ml` |
| 230 | Data Preparation | `workload_data_prep` |
| 240 | Not sure - recommend for me | `workload_unsure` |

All should be:
- **Type**: `CheckBox`
- **Variable Set**: `Step 2: Work Type`
- **Mandatory**: (unchecked)

**Variable 13: Additional Users**
1. Click **New**
2. Fill in:
   - **Type**: `List Collector`
   - **Order**: `300`
   - **Question**: `Who else needs access?`
   - **Name**: `additional_users`
   - **Variable Set**: `Step 2: Work Type`
   - **Reference**: `User [sys_user]`
   - **Mandatory**: (unchecked)

**Variable 14: Cost Estimate**
1. Click **New**
2. Fill in:
   - **Type**: `Label`
   - **Order**: `100`
   - **Question**: `Estimated Monthly Cost`
   - **Name**: `cost_estimate_display`
   - **Variable Set**: `Step 3: Review & Submit`
   - **Default value**:
     ```
     💰 $350 - $650 per month

     Actual costs may vary based on usage.
     ```

**Variable 15: Cost Confirmation**
1. Click **New**
2. Fill in:
   - **Type**: `CheckBox`
   - **Order**: `200`
   - **Question**: `I confirm this cost aligns with my funding and I have authorization to proceed`
   - **Name**: `cost_confirmation`
   - **Variable Set**: `Step 3: Review & Submit`
   - **Mandatory**: ✓

**Variable 16: Comments**
1. Click **New**
2. Fill in:
   - **Type**: `Multi Line Text`
   - **Order**: `300`
   - **Question**: `Additional Comments`
   - **Name**: `comments`
   - **Variable Set**: `Step 3: Review & Submit`
   - **Mandatory**: (unchecked)

---

## Part 3: Create PHI/AVE Catalog Item

Repeat similar steps for the PHI item. Key differences:

### Step 3.1: Create Catalog Item
- **Name**: `Request Secure PHI Research (AVE)`
- **Short description**: `Approved environment for patient data`
- **Icon**: `fa-shield`

### Step 3.2: Create 4 Variable Sets
1. `Step 1: Research & Compliance` (Order 100)
2. `Step 2: Access & Roles` (Order 200)
3. `Step 3: Environment Usage` (Order 300)
4. `Step 4: Cost & Retention` (Order 400)

### Step 3.3: Create Variables (Key ones)

**Step 1 Variables:**
- `project_name` - Single Line Text
- `principal_investigator` - Reference (User)
- `irb_number` - Single Line Text (Mandatory)
- `irb_status` - Select Box (Approved, Pending, Exempt)
- `research_purpose` - Multi Line Text

**Step 2 Variables:**
- `additional_researchers` - List Collector (User)
- `additional_analysts` - List Collector (User)
- `audit_acknowledgment` - CheckBox (Mandatory)

**Step 3 Variables:**
- `access_method` - Select Box (remote_desktop, analytics_workspace, both)
- `expected_duration` - Select Box (3_months, 6_months, 12_months)
- `renewal_reminders` - CheckBox

**Step 4 Variables:**
- `cost_estimate_display` - Label ($4,200 - $8,500)
- `funding_source` - Single Line Text (Mandatory)
- `data_retention` - Select Box (30_days, 90_days, 1_year, 7_years)
- `cost_confirmation` - CheckBox (Mandatory)

---

## Part 4: Set System Properties

### Step 4.1: Navigate to System Properties
1. Type `sys_properties.list` in navigator
2. Click **System Properties > All Properties**

### Step 4.2: Create Properties
Click **New** for each:

**Property 1:**
- **Name**: `x_umm_cloud.github_pat`
- **Type**: `password`
- **Value**: (Your GitHub Personal Access Token)

**Property 2:**
- **Name**: `x_umm_cloud.github_owner`
- **Type**: `string`
- **Value**: (Your GitHub org/username)

**Property 3:**
- **Name**: `x_umm_cloud.github_repo`
- **Type**: `string`
- **Value**: `umm-cloud-provisioning`

---

## Part 5: Create Business Rule

### Step 5.1: Navigate to Business Rules
1. Type `sys_script.list` in navigator
2. Click **System Definition > Business Rules**

### Step 5.2: Create New Business Rule
1. Click **New**
2. Fill in:
   - **Name**: `Trigger GitHub Actions - Research Computing`
   - **Table**: `Request Item [sc_req_item]`
   - **Active**: ✓
   - **Advanced**: ✓
   - **When to run**:
     - When: `after`
     - Update: ✓
   - **Filter Conditions**:
     - `State` `is` `Work in Progress`
3. In the **Advanced** tab, paste the script from `business-rule-v2.js`
4. Click **Submit**

---

## Part 6: Test the Setup

### Step 6.1: Test Standard Request
1. Navigate to **Self-Service > Service Catalog**
2. Find **Research Computing Services**
3. Click **Start Research Computing**
4. Fill in all fields and submit
5. Check that GitHub Actions workflow triggers

### Step 6.2: Test PHI Request
1. Navigate to **Self-Service > Service Catalog**
2. Click **Request Secure PHI Research (AVE)**
3. Fill in all fields and submit
4. Check workflow triggers

---

## Troubleshooting

### Business Rule Not Triggering
1. Check business rule is **Active**
2. Verify **When** is set to `after` with **Update** checked
3. Check **Filter Conditions** match your state

### GitHub Webhook Failing
1. Verify PAT has `repo` scope
2. Check system property values
3. Look at **System Logs > All** for errors

### Variables Not Showing
1. Verify Variable Set is assigned to Catalog Item
2. Check variable Order values
3. Ensure Variable Set "Display title" is checked

---

## Quick Reference: All Variables

### Standard Research (16 variables)
| Name | Type | Variable Set |
|------|------|--------------|
| project_name | Single Line Text | Step 1 |
| department | Select Box | Step 1 |
| principal_investigator | Reference | Step 1 |
| grant_code | Single Line Text | Step 1 |
| requestor_role | Select Box | Step 1 |
| expected_end_date | Date | Step 1 |
| data_type | Select Box | Step 2 |
| workload_statistical | CheckBox | Step 2 |
| workload_imaging | CheckBox | Step 2 |
| workload_ml | CheckBox | Step 2 |
| workload_data_prep | CheckBox | Step 2 |
| workload_unsure | CheckBox | Step 2 |
| additional_users | List Collector | Step 2 |
| cost_estimate_display | Label | Step 3 |
| cost_confirmation | CheckBox | Step 3 |
| comments | Multi Line Text | Step 3 |

### PHI/AVE (15 variables)
| Name | Type | Variable Set |
|------|------|--------------|
| project_name | Single Line Text | Step 1 |
| principal_investigator | Reference | Step 1 |
| irb_number | Single Line Text | Step 1 |
| irb_status | Select Box | Step 1 |
| research_purpose | Multi Line Text | Step 1 |
| additional_researchers | List Collector | Step 2 |
| additional_analysts | List Collector | Step 2 |
| audit_acknowledgment | CheckBox | Step 2 |
| access_method | Select Box | Step 3 |
| expected_duration | Select Box | Step 3 |
| renewal_reminders | CheckBox | Step 3 |
| cost_estimate_display | Label | Step 4 |
| funding_source | Single Line Text | Step 4 |
| data_retention | Select Box | Step 4 |
| cost_confirmation | CheckBox | Step 4 |
