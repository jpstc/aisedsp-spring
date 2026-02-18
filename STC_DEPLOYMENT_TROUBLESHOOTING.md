# STC Deployment Troubleshooting Guide

The **STC (Status Consumer / stc-cdbp)** service consumes messages from Azure Service Bus and persists them to SQL Database. Here's how to diagnose and fix deployment failures.

---

## Quick Diagnosis

### 1️⃣ Check Deployment Status in Azure Portal

```bash
# View deployment logs
az deployment group show -g aisedsp-spring-rg -n <deployment-name> --query "properties.provisioningState" -o tsv

# See detailed errors
az deployment group show -g aisedsp-spring-rg -n <deployment-name> --query "properties.outputs" -o json
```

### 2️⃣ Check If STC Container App Exists

```bash
# List all container apps
az containerapp list -g aisedsp-spring-rg -o table

# Check STC app specifically
az containerapp show -g aisedsp-spring-rg -n stc-cdbp --query "properties.runningState" -o tsv
```

### 3️⃣ View STC Application Logs

```bash
# Last 50 lines
az containerapp logs show -g aisedsp-spring-rg -n stc-cdbp --tail 50

# Follow logs in real-time
az containerapp logs show -g aisedsp-spring-rg -n stc-cdbp --follow
```

---

## Common Issues & Solutions

### ❌ Issue 1: "Image not found" or "Invalid image reference"

**Error message**:
```
Error: Image 'REPLACED_BY_AZD' could not be found
```

**Cause**: The Dockerfile JAR file wasn't built or the image wasn't pushed to registry.

**Solution**:

```bash
# 1. Build the JAR file
mvn clean package -DskipTests

# 2. Verify JAR was created
ls -la target/stc-cdbp-0.1.0.jar

# 3. If using Azure Container Registry, build image
az acr build -r <registry-name> -t stc-cdbp:latest .

# 4. Update the image in aca.bicep with full registry path:
# Before: image: 'REPLACED_BY_AZD'
# After: image: '<registry-name>.azurecr.io/stc-cdbp:latest'

# 5. Redeploy
az deployment group create -g aisedsp-spring-rg -f infra/aca.bicep --parameters envName=aisedsp-env kvName=<kv-name> ...
```

---

### ❌ Issue 2: "Secrets not found" (RBAC Error)

**Error message**:
```
{"innererror":{"code":"MissingSecretReference","message":"Secret 'sql-conn' not found"}}
```

**Cause**: Key Vault access denied due to RBAC issue.

**Solution**:

```bash
# 1. Check if you have Key Vault access
az keyvault secret list --vault-name <kv-name>

# If denied, add yourself as Key Vault Administrator:
az role assignment create \
  --role "Key Vault Administrator" \
  --assignee "<your-email-or-object-id>" \
  --scope /subscriptions/<subscription-id>/resourceGroups/aisedsp-spring-rg/providers/Microsoft.KeyVault/vaults/<kv-name>

# 2. Grant Container App system identity access
KV_ID=$(az keyvault show -g aisedsp-spring-rg -n <kv-name> --query id -o tsv)
PRINCIPAL_ID=$(az containerapp show -g aisedsp-spring-rg -n stc-cdbp --query identity.principalId -o tsv)

az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id "$PRINCIPAL_ID" \
  --scope "$KV_ID"

# 3. Verify secrets exist in Key Vault
az keyvault secret show --vault-name <kv-name> --name sql-connection-string
az keyvault secret show --vault-name <kv-name> --name servicebus-connection-string
```

---

### ❌ Issue 3: "SQL Connection Failed"

**Error message in logs**:
```
java.sql.SQLException: Login failed for user 'sqladmin'
com.microsoft.sqlserver.jdbc.SQLServerException: Cannot open server 'sql-aisedsp-...' requested by the login
```

**Cause**: 
- SQL Server firewall doesn't allow Azure services
- Connection string is incorrect
- SQL Server is paused

**Solution**:

```bash
# 1. Check SQL Server status
SQL_SERVER=$(az sql server list -g aisedsp-spring-rg --query "[0].name" -o tsv)
az sql server show -g aisedsp-spring-rg -n "$SQL_SERVER" --query "state" -o tsv

# If paused, resume it
az sql server resume -g aisedsp-spring-rg -n "$SQL_SERVER"

# 2. Enable "Allow Azure services" firewall rule
az sql server firewall-rule create \
  -g aisedsp-spring-rg \
  -s "$SQL_SERVER" \
  -n AllowAllAzureIps \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# 3. Verify connection string format
az keyvault secret show \
  --vault-name <kv-name> \
  --name sql-connection-string \
  --query "value" -o tsv

# Expected format:
# Server=tcp:sql-aisedsp-XXXX.database.windows.net,1433;Initial Catalog=db-aisedsp;Persist Security Info=False;User ID=sqladmin;Password=...;Encrypt=True;...

# 4. Restart STC container app
az containerapp up -g aisedsp-spring-rg -n stc-cdbp
```

---

### ❌ Issue 4: "Service Bus Connection Failed"

**Error message in logs**:
```
com.azure.messaging.servicebus.ServiceBusException: Failed to authenticate
```

**Cause**: Service Bus connection string is invalid or missing.

**Solution**:

```bash
# 1. Verify SB connection string exists
SERVICE_BUS=$(az servicebus namespace list -g aisedsp-spring-rg --query "[0].name" -o tsv)
az keyvault secret show --vault-name <kv-name> --name servicebus-connection-string

# 2. If missing, create it
az servicebus namespace authorization-rule keys list \
  -g aisedsp-spring-rg \
  --namespace-name "$SERVICE_BUS" \
  -n RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv | \
  az keyvault secret set --vault-name <kv-name> --name servicebus-connection-string --value @-

# 3. Verify topic and subscription exist
az servicebus topic list -g aisedsp-spring-rg --namespace-name "$SERVICE_BUS"
az servicebus topic subscription list \
  -g aisedsp-spring-rg \
  --namespace-name "$SERVICE_BUS" \
  -t doc-status

# If subscription doesn't exist, create it
az servicebus topic subscription create \
  -g aisedsp-spring-rg \
  --namespace-name "$SERVICE_BUS" \
  -t doc-status \
  -n stc-cdbp
```

---

### ❌ Issue 5: "CrashLoopBackOff" - Container Keeps Restarting

**Cause**: Application crashes shortly after startup.

**Solution**:

```bash
# 1. Check recent logs (before crash)
az containerapp logs show -g aisedsp-spring-rg -n stc-cdbp --tail 100

# 2. Common causes:
#    - Missing environment variables
#    - Database initialization fails
#    - Compilation error

# 3. Check environment variables are set correctly
az containerapp show -g aisedsp-spring-rg -n stc-cdbp \
  --query "properties.template.containers[0].env[*].[name, value]" -o table

# 4. Verify database exists and is online
DB_SERVER=$(az sql server list -g aisedsp-spring-rg --query "[0].name" -o tsv)
az sql db list -g aisedsp-spring-rg -s "$DB_SERVER" -o table
az sql db show -g aisedsp-spring-rg -s "$DB_SERVER" -n db-aisedsp --query "status" -o tsv
```

---

### ❌ Issue 6: "Port Already in Use" or "Ingress Configuration Error"

**Error message**:
```
Port 8081 is already bound
```

**Solution**:

```bash
# Check what's running on port
az containerapp show -g aisedsp-spring-rg -n stc-cdbp --query "properties.configuration.ingress" -o json

# Update Bicep to use different port if needed
# In aca.bicep, change:
# ingress: { external: true, targetPort: 8081 }
# to:
# ingress: { external: true, targetPort: 8082 }

# Then redeploy
```

---

## Complete Deployment Reset

If the above doesn't work, reset and redeploy:

```bash
# 1. Delete the failed STC container app
az containerapp delete -g aisedsp-spring-rg -n stc-cdbp --yes

# 2. Rebuild the JAR
mvn clean package -DskipTests

# 3. Verify secrets are set in Key Vault
az keyvault secret list --vault-name <kv-name> -o table

# 4. Redeploy via Bicep
cd infra
az deployment group create \
  -g aisedsp-spring-rg \
  -f aca.bicep \
  --parameters \
    location=eastus \
    envName=aisedsp-env \
    kvName=<kv-name> \
    sqlConnSecretName=sql-connection-string \
    sbConnSecretName=servicebus-connection-string

# 5. Wait for deployment (2-5 minutes)
az containerapp show -g aisedsp-spring-rg -n stc-cdbp --query "properties.runningState" -o tsv

# 6. Check logs
az containerapp logs show -g aisedsp-spring-rg -n stc-cdbp --tail 50
```

---

## Verification Checklist

Before deployment, verify all prerequisites:

- ✅ **Java 17+** is installed: `java -version`
- ✅ **Maven 3.8+** is installed: `mvn -version`
- ✅ **Azure CLI** is installed: `az --version`
- ✅ **Logged into Azure**: `az account show`
- ✅ **JAR file built**: `ls target/stc-cdbp-0.1.0.jar`
- ✅ **Resource Group exists**: `az group show -n aisedsp-spring-rg`
- ✅ **Key Vault exists**: `az keyvault list -g aisedsp-spring-rg`
- ✅ **SQL Server exists**: `az sql server list -g aisedsp-spring-rg`
- ✅ **Service Bus exists**: `az servicebus namespace list -g aisedsp-spring-rg`
- ✅ **Secrets in Key Vault**:
  ```bash
  az keyvault secret list --vault-name <kv-name> --query "[].name" -o table
  ```

---

## STC Service Details

**STC = Status Consumer (stc-cdbp)**

| Aspect | Value |
|--------|-------|
| **Purpose** | Consumes Service Bus messages and persists to SQL |
| **Language** | Java 17 |
| **Framework** | Spring Boot 3.2.6 |
| **Port** | 8081 |
| **Key Dependencies** | Azure Service Bus, SQL Server, Spring Data JPA |
| **Environment Variables** | `SQL_CONN`, `SB_CONN`, `SB_TOPIC`, `SB_SUB` |
| **Entry Point** | `StatusConsumer` - listens on Service Bus topic |

**Service Bus Configuration**:
- Topic: `doc-status`
- Subscription: `stc-cdbp`
- Processes: Document status messages

---

## Getting Help

If issues persist:

1. **Collect diagnostics**: `bash infra/scripts/diagnose.sh aisedsp-spring-rg`
2. **Check logs**: `az containerapp logs show -g aisedsp-spring-rg -n stc-cdbp --tail 100`
3. **Verify all resources**: `bash infra/scripts/verify-azure-cli.sh aisedsp-spring-rg`
4. **Check Azure Portal**: 
   - Resource Group > stc-cdbp > Logs (Log Stream)
   - Container App > Revisions
   - Key Vault > Secrets

---

## Quick Commands Reference

```bash
# Build
mvn clean package -DskipTests

# Check STC status
az containerapp show -g aisedsp-spring-rg -n stc-cdbp --query "properties.runningState" -o tsv

# View logs
az containerapp logs show -g aisedsp-spring-rg -n stc-cdbp --tail 50

# Get STC URL
az containerapp show -g aisedsp-spring-rg -n stc-cdbp --query "properties.configuration.ingress.fqdn" -o tsv

# Restart STC
az containerapp update -g aisedsp-spring-rg -n stc-cdbp --no-wait

# Delete and redeploy
az containerapp delete -g aisedsp-spring-rg -n stc-cdbp --yes
az deployment group create -g aisedsp-spring-rg -f infra/aca.bicep --parameters location=eastus envName=aisedsp-env kvName=kv-aisedsp-XXXX sqlConnSecretName=sql-connection-string sbConnSecretName=servicebus-connection-string
```
