# Azure CLI Scripts - Verification & Testing Guide

This guide explains how to run all verification and testing scripts for the AISEDSP-Spring project on Azure.

---

## Prerequisites

- **Azure CLI** installed: [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **curl** installed (for HTTP requests)
- **Logged into Azure**: Run `az login`
- **Correct subscription**: Run `az account set --subscription <subscription-id>`
- **Resource group deployed**: Ensure your ARM template or Bicep deployment is complete

---

## Quick Start (Recommended)

If you want to verify everything and run tests quickly:

```bash
# 1. Verify all Azure resources are deployed correctly
bash infra/scripts/verify-azure-cli.sh <resource-group-name>

# 2. Obtain app URL and run API tests automatically
bash infra/scripts/quick-test.sh <resource-group-name>
```

---

## Individual Scripts

### 1. **verify-azure-cli.sh** - Complete Resource Verification

**Purpose**: Validates that all required Azure resources are deployed and configured correctly.

**What it checks**:
- ✅ Azure CLI installation and authentication
- ✅ Resource group exists and subscription is correct
- ✅ All key resources exist: Key Vault, SQL Server, Service Bus, Log Analytics, Container Apps, API Management
- ✅ Key Vault secrets are present and accessible
- ✅ SQL Server and databases are accessible
- ✅ SQL firewall rules allow Azure services
- ✅ Service Bus namespace is active
- ✅ Container Apps and their running state
- ✅ Container App URLs/FQDNs
- ✅ API Management provisioning state

**Usage**:

```bash
# Basic usage (default resource group: "aisedsp-spring-rg")
bash infra/scripts/verify-azure-cli.sh

# With custom resource group
bash infra/scripts/verify-azure-cli.sh my-resource-group

# With custom resource group and subscription
bash infra/scripts/verify-azure-cli.sh my-resource-group "subscription-id"
```

**Example output**:
```
═══════════════════════════════════════════════════════════
AISEDSP-SPRING Azure Deployment Verification
═══════════════════════════════════════════════════════════

▶ 1. Checking Azure CLI installation
✅ Azure CLI is installed

▶ 2. Checking Azure login status
✅ Logged in as: user@example.com
   Set subscription to: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

▶ 3. Verifying resource group
✅ Resource group 'aisedsp-spring-rg' exists
   Location: eastus

▶ 4. Verifying deployed resources
✅ Key Vault found (1)
✅ SQL Server found (1)
✅ Service Bus found (1)
...
```

---

### 2. **diagnose.sh** - Deployment Diagnostics

**Purpose**: Provides diagnostic information about the current deployment, including logs and configuration details.

**What it shows**:
- Container Apps information and recent logs
- SQL Server and database details
- Key Vault secrets
- Service Bus namespace info
- API Management details

**Usage**:

```bash
# Basic usage
bash infra/scripts/diagnose.sh

# With custom resource group
bash infra/scripts/diagnose.sh my-resource-group
```

**Example output**:
```
═══════════════════════════════════════════════════════════
DIAGNOSTIKA AISEDSP-SPRING DEPLOYMENT
═══════════════════════════════════════════════════════════

📦 CONTAINER APPS - MZV Service
—————————————————————————————
✅ Aplikace: mzv-service
✅ URL: mzv-service.abcd1234.eastus.azurecontainerapps.io
Posledních 50 řádků logu:
  [INFO] Started Application in 2.345 seconds
  [INFO] Listening on port 8080
  ...
```

---

### 3. **quick-test.sh** - Quick Setup & Testing

**Purpose**: Automates the process of finding your app URL in Azure and running API tests.

**What it does**:
1. Finds the MZV Container App in your resource group
2. Obtains the application URL
3. Verifies the app is running (health check)
4. Runs the full API test suite

**Usage**:

```bash
# Interactive (prompts for resource group)
bash infra/scripts/quick-test.sh

# Non-interactive (specify resource group)
bash infra/scripts/quick-test.sh my-resource-group
```

**Expected output**:
```
═══════════════════════════════════════════════════════════
QUICK TEST SETUP
═══════════════════════════════════════════════════════════

🔍 Hledám aplikace v resource group: aisedsp-spring-rg

✅ Najdena aplikace: mzv-service
✅ URL: https://mzv-service.abcd1234.eastus.azurecontainerapps.io
🔍 Ověřuji, že aplikace běží...
✅ Aplikace běží!

═══════════════════════════════════════════════════════════
🧪 SPOUŠTĚNÍ TESTŮ
═══════════════════════════════════════════════════════════

[Runs test-api.sh automatically]
```

---

### 4. **test-api.sh** - API Endpoint Testing

**Purpose**: Tests all CRUD operations on the Document API.

**What it tests**:
1. ✅ Health check (`GET /actuator/health`)
2. ✅ Create document (`POST /api/documents`)
3. ✅ Read document (`GET /api/documents/{id}`)
4. ✅ Update document (`PUT /api/documents/{id}`)
5. ✅ Delete document (`DELETE /api/documents/{id}`)

**Usage**:

```bash
# Test against Azure-deployed app
bash infra/scripts/test-api.sh https://mzv-service.abcd1234.eastus.azurecontainerapps.io

# Test against local development app
bash infra/scripts/test-api.sh http://localhost:8081

# Default (uses http://localhost:8081)
bash infra/scripts/test-api.sh
```

**Expected output**:
```
═══════════════════════════════════════════════════════════
TEST API - Uložení a načtení dokumentu
═══════════════════════════════════════════════════════════

URL: https://mzv-service.abcd1234.eastus.azurecontainerapps.io

1️⃣  HEALTH CHECK
—————————————————————————————
GET /actuator/health
Status: 200
Response: {"status":"UP"}

2️⃣  VYTVOŘENÍ DOKUMENTU
—————————————————————————————
POST /api/documents
Payload: {"title": "TestDocument-1708277123", "status": "NEW"}
Status: 201
Response: {"id":1,"title":"TestDocument-1708277123","status":"NEW"}
✅ Záznam vytvořen, ID: 1

3️⃣  NAČTENÍ DOKUMENTU
—————————————————————————————
GET /api/documents/1
Status: 200
Response: {"id":1,"title":"TestDocument-1708277123","status":"NEW"}
✅ Záznam úspěšně načten

4️⃣  AKTUALIZACE DOKUMENTU
—————————————————————————————
PUT /api/documents/1
Status: 200
Response: {"id":1,"title":"TestDocument-1708277123 - UPDATED","status":"PROCESSED"}
✅ Záznam úspěšně aktualizován

5️⃣  SMAZÁNÍ DOKUMENTU
—————————————————————————————
DELETE /api/documents/1
Status: 204
✅ Záznam úspěšně smazán

═══════════════════════════════════════════════════════════
✅ VŠECHNY TESTY PROŠLY!
═══════════════════════════════════════════════════════════
```

---

### 5. **postprovision.sh** - Post-Deployment Configuration

**Purpose**: Runs post-deployment configuration tasks (e.g., applying API Management policies).

**Usage**:

```bash
bash infra/scripts/postprovision.sh
```

**Note**: This script is currently a placeholder. It can be expanded to:
- Apply APIM policies (rate limiting, JWT validation, IP filtering)
- Initialize database schemas
- Configure logging and monitoring

---

## Complete Verification Workflow

Here's the recommended step-by-step workflow after deployment:

### Step 1: Initial Verification
```bash
# Verify all resources are deployed
bash infra/scripts/verify-azure-cli.sh aisedsp-spring-rg
```

**Expected result**: ✅ All checks passed (green output)

**If any checks fail**:
- Review the error messages
- Consult [VERIFICATION_GUIDE.md](../VERIFICATION_GUIDE.md)
- Check [KEYVAULT_RBAC_FIX.md](../KEYVAULT_RBAC_FIX.md) for access issues
- Review [DEBUGGING_GUIDE.md](../docs/DEBUGGING_GUIDE.md) for troubleshooting

### Step 2: Diagnostic Deep Dive
```bash
# Get detailed diagnostic information
bash infra/scripts/diagnose.sh aisedsp-spring-rg
```

**Expected result**: Shows all resource details, app URLs, and recent logs

### Step 3: Run Full API Tests
```bash
# Automatically find app and run tests
bash infra/scripts/quick-test.sh aisedsp-spring-rg
```

**Expected result**: ✅ All API tests pass

### Step 4: Manual API Testing (Optional)
```bash
# If you need to test specific endpoints
APP_URL="https://mzv-service.abcd1234.eastus.azurecontainerapps.io"
bash infra/scripts/test-api.sh "$APP_URL"
```

---

## Troubleshooting

### Script shows "Not logged in to Azure"
```bash
az login
az account set --subscription <subscription-id>
```

### "Resource group not found"
```bash
# List available resource groups
az group list --query "[].name" -o table

# Use the correct name in scripts
bash infra/scripts/verify-azure-cli.sh <correct-resource-group-name>
```

### API tests fail with "Application not available"
1. Check if Container App is running:
   ```bash
   bash infra/scripts/diagnose.sh <resource-group>
   ```

2. View recent logs:
   ```bash
   az containerapp logs show -g <resource-group> -n mzv-service --tail 50
   ```

3. Wait for app to start (can take 1-2 minutes after deployment)

### SQL connection errors
1. Verify connection string in Key Vault:
   ```bash
   az keyvault secret show --vault-name <kv-name> --name sql-connection-string
   ```

2. Check SQL firewall allows Azure services:
   ```bash
   az sql server firewall-rule list -g <resource-group> -s <sql-server-name>
   ```

### Key Vault access denied (RBAC error)
See [KEYVAULT_RBAC_FIX.md](../KEYVAULT_RBAC_FIX.md)

---

## CI/CD Integration

These scripts can be integrated into your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Verify Azure Deployment
  run: |
    bash infra/scripts/verify-azure-cli.sh ${{ secrets.AZURE_RESOURCE_GROUP }}
  env:
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Run API Tests
  run: |
    bash infra/scripts/quick-test.sh ${{ secrets.AZURE_RESOURCE_GROUP }}
```

---

## Exit Codes

Scripts return standard exit codes for automation:
- `0` - Success
- `1` - Failure

Use in scripts:
```bash
if bash infra/scripts/verify-azure-cli.sh aisedsp-spring-rg; then
  echo "✅ Verification passed"
else
  echo "❌ Verification failed"
  exit 1
fi
```

---

## Additional Resources

- [Azure CLI Documentation](https://learn.microsoft.com/cli/azure/)
- [Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure Service Bus Documentation](https://learn.microsoft.com/azure/service-bus-messaging/)
- [Azure SQL Database Documentation](https://learn.microsoft.com/azure/azure-sql/)
- Project guides: [VERIFICATION_GUIDE.md](../VERIFICATION_GUIDE.md), [DEBUGGING_GUIDE.md](../docs/DEBUGGING_GUIDE.md)
