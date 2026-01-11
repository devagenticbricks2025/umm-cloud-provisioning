# ServiceNow Setup Guide - Research Computing Services
## Step-by-Step Instructions

---

## Prerequisites
- ServiceNow Developer Instance (active)
- Admin access
- ~45 minutes for setup

---

## Part 1: Create Category

### Step 1.1: Navigate to Categories
1. In the Filter Navigator (left sidebar), type: `sc_category.list`
2. Press Enter

### Step 1.2: Create New Category
1. Click **New**
2. Fill in:
   - **Title**: `Research Computing Services`
   - **Description**: `Self-service research computing and PHI environments`
   - **Catalog**: Select `Service Catalog`
   - **Active**: ✓ (checked)
3. Click **Submit**

---

## Part 2: Create Standard Research Computing Catalog Item

### Step 2.1: Navigate to Catalog Items
1. In the Filter Navigator, type: `sc_cat_item.list`
2. Press Enter

### Step 2.2: Create the Catalog Item
1. Click **New**
2. Fill in:
   - **Name**: `Start Research Computing`
   - **Catalogs**: Select `Service Catalog`
   - **Category**: Select `Research Computing Services`
   - **Short description**: `Simple compute and storage for research`
3. Click **Submit**
4. **Re-open** the item you just created (click on its name)

### Step 2.3: Create Variable Sets
Scroll down to the **Variable Sets** related list and create these:

**Variable Set 1:**
1. Click **New** in the Variable Sets section
2. Fill in:
   - **Title**: `Step 1: About Your Research`
   - **Order**: `100`
   - **Display title**: ✓ (checked)
3. Click **Submit**

**Variable Set 2:**
1. Click **New**
2. Fill in:
   - **Title**: `Step 2: Work Type`
   - **Order**: `200`
   - **Display title**: ✓ (checked)
3. Click **Submit**

**Variable Set 3:**
1. Click **New**
2. Fill in:
   - **Title**: `Step 3: Review & Submit`
   - **Order**: `300`
   - **Display title**: ✓ (checked)
3. Click **Submit**

---

## Part 3: Create Variables (from Variable Sets)

### Step 3.1: Add Variables to "Step 1: About Your Research"

1. From the Catalog Item, click on **Variable Sets** tab
2. Click on **`Step 1: About Your Research`** to open it
3. Scroll down to find **Variables** related list
4. Create each variable by clicking **New**:

**Variable 1: Project Name**
| Field | Value |
|-------|-------|
| Type | `Single Line Text` |
| Order | `100` |
| Question | `Research Project Name` |
| Name | `project_name` |
| Mandatory | ✓ |
| Example Text | `Enter a descriptive name for your research project` |

Click **Submit**, then **New** for the next variable.

**Variable 2: Department**
| Field | Value |
|-------|-------|
| Type | `Select Box` |
| Order | `200` |
| Question | `Department` |
| Name | `department` |
| Mandatory | ✓ |

Click **Submit**. Then re-open this variable and scroll to **Question Choices**. Add:
- Value: `internal_medicine` | Label: `Internal Medicine`
- Value: `radiology` | Label: `Radiology`
- Value: `cardiology` | Label: `Cardiology`
- Value: `oncology` | Label: `Oncology`
- Value: `neurology` | Label: `Neurology`
- Value: `other` | Label: `Other`

**Variable 3: Principal Investigator**
| Field | Value |
|-------|-------|
| Type | `Reference` |
| Order | `300` |
| Question | `Principal Investigator` |
| Name | `principal_investigator` |
| Mandatory | ✓ |
| Reference | `User [sys_user]` |

**Variable 4: Grant Code**
| Field | Value |
|-------|-------|
| Type | `Single Line Text` |
| Order | `400` |
| Question | `Grant/Project Code` |
| Name | `grant_code` |
| Mandatory | (unchecked) |

**Variable 5: Requestor Role**
| Field | Value |
|-------|-------|
| Type | `Select Box` |
| Order | `500` |
| Question | `Your Role` |
| Name | `requestor_role` |
| Mandatory | ✓ |

After submit, add choices:
- Value: `researcher` | Label: `Researcher`
- Value: `analyst` | Label: `Analyst`
- Value: `lab_manager` | Label: `Lab Manager`
- Value: `student` | Label: `Student`

**Variable 6: End Date**
| Field | Value |
|-------|-------|
| Type | `Date` |
| Order | `600` |
| Question | `Expected Project End Date` |
| Name | `expected_end_date` |
| Mandatory | ✓ |

---

### Step 3.2: Add Variables to "Step 2: Work Type"

1. Go back to the Catalog Item
2. Click on **Variable Sets** tab
3. Click on **`Step 2: Work Type`** to open it
4. Scroll to **Variables** related list and create:

**Variable 7: Data Type**
| Field | Value |
|-------|-------|
| Type | `Select Box` |
| Order | `100` |
| Question | `What type of data will you be working with?` |
| Name | `data_type` |
| Mandatory | ✓ |

After submit, add choices:
- Value: `non_phi` | Label: `Non-PHI (No patient data)`
- Value: `phi` | Label: `PHI - Use AVE Request Instead`

**Variables 8-12: Workload Checkboxes**

Create these 5 checkbox variables:

| Order | Question | Name | Type |
|-------|----------|------|------|
| 200 | Statistical Analysis | `workload_statistical` | CheckBox |
| 210 | Imaging Analysis | `workload_imaging` | CheckBox |
| 220 | Machine Learning / AI | `workload_ml` | CheckBox |
| 230 | Data Preparation | `workload_data_prep` | CheckBox |
| 240 | Not sure - recommend for me | `workload_unsure` | CheckBox |

All should have Mandatory: (unchecked)

**Variable 13: Additional Users**
| Field | Value |
|-------|-------|
| Type | `List Collector` |
| Order | `300` |
| Question | `Who else needs access?` |
| Name | `additional_users` |
| Mandatory | (unchecked) |
| List Table | `User [sys_user]` |

---

### Step 3.3: Add Variables to "Step 3: Review & Submit"

1. Go back to the Catalog Item
2. Click on **Variable Sets** tab
3. Click on **`Step 3: Review & Submit`** to open it
4. Create these variables:

**Variable 14: Cost Estimate Display**
| Field | Value |
|-------|-------|
| Type | `Label` |
| Order | `100` |
| Question | `Estimated Monthly Cost` |
| Name | `cost_estimate_display` |
| Default Value | `$350 - $650 per month. Actual costs may vary based on usage.` |

**Variable 15: Cost Confirmation**
| Field | Value |
|-------|-------|
| Type | `CheckBox` |
| Order | `200` |
| Question | `I confirm this cost aligns with my funding and I have authorization to proceed` |
| Name | `cost_confirmation` |
| Mandatory | ✓ |

**Variable 16: Comments**
| Field | Value |
|-------|-------|
| Type | `Multi Line Text` |
| Order | `300` |
| Question | `Additional Comments` |
| Name | `comments` |
| Mandatory | (unchecked) |

---

## Part 4: Create PHI/AVE Catalog Item

Repeat similar steps for the PHI catalog item:

### Step 4.1: Create Catalog Item
1. Navigate to `sc_cat_item.list`
2. Click **New**
3. Fill in:
   - **Name**: `Request Secure PHI Research (AVE)`
   - **Catalogs**: `Service Catalog`
   - **Category**: `Research Computing Services`
   - **Short description**: `Approved environment for patient data`
4. Click **Submit** and re-open

### Step 4.2: Create 4 Variable Sets
| Title | Order |
|-------|-------|
| `Step 1: Research & Compliance` | 100 |
| `Step 2: Access & Roles` | 200 |
| `Step 3: Environment Usage` | 300 |
| `Step 4: Cost & Retention` | 400 |

### Step 4.3: Create Variables

**Step 1: Research & Compliance Variables:**
| Order | Question | Name | Type | Mandatory |
|-------|----------|------|------|-----------|
| 100 | Research Project Name | `project_name` | Single Line Text | ✓ |
| 200 | Principal Investigator | `principal_investigator` | Reference (User) | ✓ |
| 300 | IRB Protocol Number | `irb_number` | Single Line Text | ✓ |
| 400 | IRB Status | `irb_status` | Select Box | ✓ |
| 500 | Research Purpose | `research_purpose` | Multi Line Text | ✓ |

IRB Status choices: `approved`/Approved, `pending`/Pending Approval, `exempt`/Exempt

**Step 2: Access & Roles Variables:**
| Order | Question | Name | Type | Mandatory |
|-------|----------|------|------|-----------|
| 100 | Additional Researchers | `additional_researchers` | List Collector (User) | No |
| 200 | Additional Analysts | `additional_analysts` | List Collector (User) | No |
| 300 | I understand all access is logged and audited | `audit_acknowledgment` | CheckBox | ✓ |

**Step 3: Environment Usage Variables:**
| Order | Question | Name | Type | Mandatory |
|-------|----------|------|------|-----------|
| 100 | How will you access this environment? | `access_method` | Select Box | ✓ |
| 200 | Expected Duration | `expected_duration` | Select Box | ✓ |
| 300 | Send renewal reminders | `renewal_reminders` | CheckBox | No |

Access Method choices: `remote_desktop`/Secure Remote Desktop, `analytics_workspace`/Analytics Workspace (Databricks), `both`/Both

Duration choices: `3_months`/3 months, `6_months`/6 months, `12_months`/12 months, `24_months`/24 months

**Step 4: Cost & Retention Variables:**
| Order | Question | Name | Type | Mandatory |
|-------|----------|------|------|-----------|
| 100 | Estimated Monthly Cost | `cost_estimate_display` | Label | No |
| 200 | Funding Source / Grant Code | `funding_source` | Single Line Text | ✓ |
| 300 | Data Retention Requirement | `data_retention` | Select Box | ✓ |
| 400 | I confirm this cost aligns with my funding | `cost_confirmation` | CheckBox | ✓ |
| 500 | Additional Comments | `comments` | Multi Line Text | No |

Cost Estimate Default: `$4,200 - $8,500 per month (includes HIPAA-compliant infrastructure)`

Data Retention choices: `30_days`/30 days, `90_days`/90 days, `1_year`/1 year, `7_years`/7 years (HIPAA)

---

## Part 5: Set System Properties

### Step 5.1: Navigate to System Properties
1. In Filter Navigator, type: `sys_properties.list`
2. Press Enter

### Step 5.2: Create Properties
Click **New** for each:

**Property 1: GitHub PAT**
- **Name**: `x_umm_cloud.github_pat`
- **Type**: `string`
- **Value**: (Your GitHub Personal Access Token with repo scope)

**Property 2: GitHub Owner**
- **Name**: `x_umm_cloud.github_owner`
- **Type**: `string`
- **Value**: (Your GitHub org/username)

**Property 3: GitHub Repo**
- **Name**: `x_umm_cloud.github_repo`
- **Type**: `string`
- **Value**: `umm-cloud-provisioning`

---

## Part 6: Create Business Rule

### Step 6.1: Navigate to Business Rules
1. In Filter Navigator, type: `sys_script.list`
2. Press Enter

### Step 6.2: Create New Business Rule
1. Click **New**
2. Fill in:
   - **Name**: `Trigger GitHub Actions - Research Computing`
   - **Table**: `Request Item [sc_req_item]`
   - **Active**: ✓
   - **Advanced**: ✓
3. In **When to run** tab:
   - **When**: `after`
   - **Update**: ✓
4. In **Filter Conditions**:
   - Add: `State` `is` `Work in Progress`
5. In **Advanced** tab, paste the script from `business-rule-v2.js`
6. Click **Submit**

---

## Part 7: Test

### Test Standard Request
1. Go to: `https://YOUR-INSTANCE.service-now.com/sp`
2. Search for "Research Computing"
3. Click **Start Research Computing**
4. Fill in all fields and submit
5. Approve the request (set state to "Work in Progress")
6. Check GitHub Actions for triggered workflow

### Test PHI Request
1. Click **Request Secure PHI Research (AVE)**
2. Fill in all fields and submit
3. Approve and verify GitHub Actions triggers

---

## Quick Reference: Variable Names

### Standard Research (16 variables)
```
project_name, department, principal_investigator, grant_code,
requestor_role, expected_end_date, data_type, workload_statistical,
workload_imaging, workload_ml, workload_data_prep, workload_unsure,
additional_users, cost_estimate_display, cost_confirmation, comments
```

### PHI/AVE (15 variables)
```
project_name, principal_investigator, irb_number, irb_status,
research_purpose, additional_researchers, additional_analysts,
audit_acknowledgment, access_method, expected_duration,
renewal_reminders, cost_estimate_display, funding_source,
data_retention, cost_confirmation, comments
```

---

## Troubleshooting

### Variables Not Showing in Form
- Ensure Variable Set has **Display title** checked
- Check variable **Order** values (lower = appears first)
- Verify Variable Set is linked to the Catalog Item

### Business Rule Not Triggering
- Check business rule is **Active**
- Verify **When** is set to `after` with **Update** checked
- Check **Filter Conditions** match your state

### GitHub Webhook Failing
- Verify PAT has `repo` scope
- Check system property values are correct
- Look at **System Logs > All** for errors
