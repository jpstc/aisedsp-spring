# Debugging a testování v Azure cloudu

## 📋 Krok 1: Příprava

### Prerequisity
```bash
# Ověřit přihlášení
az account show

# Ověřit access k subscription
az group list --query "[].name" -o table
```

### Zisk informací o deploymentu
```bash
# Najít Resource Group (pokud nevíte jméno)
az group list --query "[?contains(name, 'aisedsp')] | [].{Name: name, Location: location}" -o table

# Nebo získat z Azure Portal - rg jméno
RG="your-resource-group-name"
```

## 🔍 Krok 2: Diagnostika

### Spustit diagnostiku
```bash
bash infra/scripts/diagnose.sh $RG
```

Tento script vám ukáže:
- ✅ Container Apps (MZV a STC aplikace)
- ✅ SQL Database konektivitu
- ✅ Key Vault a secrets
- ✅ Service Bus
- ✅ API Management
- ✅ Poslední logy z aplikací

### Hlavní věci k ověření:
1. **Container Apps běží?** (status = active)
2. **SQL Database je dostupná?** (firewall rules)
3. **Environment variables jsou správně nastaveny?** (SQL_CONN v ContainerApp)

## 🧪 Krok 3: Testování API

### Získat URL aplikace
```bash
# MZV service URL
MZV_URL=$(az containerapp show -g $RG -n $(az containerapp list -g $RG --query "[?contains(name, 'mzv')] | [0].name" -o tsv) --query "properties.configuration.ingress.fqdn" -o tsv | sed 's/^/https:\/\//')

echo "MZV URL: $MZV_URL"
```

### Spustit end-to-end test (Create → Read → Update → Delete)
```bash
bash infra/scripts/test-api.sh "$MZV_URL"
```

Test simuluje:
1. ✅ Health check aplikace
2. ✅ POST - Uložení dokumentu do DB
3. ✅ GET - Načtení dokumentu z DB
4. ✅ PUT - Aktualizace dokumentu
5. ✅ DELETE - Smazání dokumentu

## 🐛 Troubleshooting

### ❌ Aplikace není dostupná (HTTP 503/502)
```bash
# Zkontrolovat logy
az containerapp logs show -g $RG -n $MZV_APP --tail 100

# Restartovat aplikaci
az containerapp update -g $RG -n $MZV_APP --restart-now
```

### ❌ SQL Connection Failed
```bash
# Zkontrolovat connection string v Key Vault
az keyvault secret show --vault-name $KV -n "sql-connection-string" --query "value" -o tsv

# Zkontrolovat SQL Server firewall
az sql server firewall-rule list -g $RG -s $SQL_SERVER --output table

# Přidat Container Apps managed identity
# (mělo by být v Bicep, ale zkontrolovat)
az sql server ad-admin show -g $RG -s $SQL_SERVER
```

### ❌ "Constraint violation" / "NOT NULL failed"
```
Problém: Field validation selhal (title nebo status field prázdný)
Řešení: Zkontrolovat JSON payload v testu
```

## 🚀 Krok 4: Ruční test přes curl

### Create (POST)
```bash
curl -X POST "https://<app-url>/api/documents" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Můj dokument",
    "status": "NEW"
  }'
```

Očekávaná odpověď:
```json
{
  "id": 1,
  "title": "Můj dokument",
  "status": "NEW"
}
```

### Read (GET)
```bash
curl "https://<app-url>/api/documents/1"
```

### Update (PUT)
```bash
curl -X PUT "https://<app-url>/api/documents/1" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Aktualizovaný dokument",
    "status": "PROCESSED"
  }'
```

### Delete (DELETE)
```bash
curl -X DELETE "https://<app-url>/api/documents/1"
```

## 📊 Monitoring

### Živé logy
```bash
# Real-time logy
az containerapp logs show -g $RG -n $MZV_APP --follow --tail 50
```

### Metriky v Azure Portal
1. Jít na Resource Group → Container App (MZV)
2. V menu "Monitoring" → "Logs" (Application Insights)
3. Query: `requests | where name contains "api/documents"`

## ✅ Kontrolní seznam pro ověření

- [ ] Diagnostika projde bez chyb
- [ ] API vrací HTTP 200 na health check
- [ ] POST vytvoří záznam v DB (HTTP 201)
- [ ] GET vrátí uložený záznam (HTTP 200)
- [ ] PUT aktualizuje záznam (HTTP 200)
- [ ] DELETE smaže záznam (HTTP 204)
- [ ] Logy neobsahují chyby

## 🔗 Užitečné linky

- Azure Container Apps: https://portal.azure.com → Container Apps
- SQL Database: https://portal.azure.com → SQL databases
- Application Insights: https://portal.azure.com → Application Insights

---

## Příklad kompletní diagnostiky

```bash
# Nastavit RG jméno
export RG="aisedsp-spring-rg"

# 1. Diagnostika
echo "=== DIAGNOSTIKA ===" 
bash infra/scripts/diagnose.sh $RG

# 2. Získat URL
export MZV_URL=$(az containerapp show -g $RG -n $(az containerapp list -g $RG --query "[?contains(name, 'mzv')] | [0].name" -o tsv) --query "properties.configuration.ingress.fqdn" -o tsv | sed 's/^/https:\/\//')
echo "URL: $MZV_URL"

# 3. Test API
echo "=== TEST API ===" 
bash infra/scripts/test-api.sh "$MZV_URL"

# 4. Logy
echo "=== POSLEDNÍ LOGY ===" 
az containerapp logs show -g $RG -n $(az containerapp list -g $RG --query "[?contains(name, 'mzv')] | [0].name" -o tsv) --tail 50
```
