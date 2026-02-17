#!/bin/bash
# Diagnostika Azure deployment
# Spustit: bash infra/scripts/diagnose.sh <resource-group-name>

RG=${1:-"aisedsp-spring-rg"}

echo "═══════════════════════════════════════════════"
echo "DIAGNOSTIKA AISEDSP-SPRING DEPLOYMENT"
echo "═══════════════════════════════════════════════"
echo ""

# 1. Container Apps - info a logs
echo "📦 CONTAINER APPS - MZV Service"
echo "—————————————————————————————"
MZV_APP=$(az containerapp list -g "$RG" --query "[?contains(name, 'mzv')] | [0].name" -o tsv 2>/dev/null)
if [ -z "$MZV_APP" ]; then
  echo "❌ Nenalezena MZV aplikace"
else
  echo "✅ Aplikace: $MZV_APP"
  echo ""
  echo "URL:"
  az containerapp show -g "$RG" -n "$MZV_APP" --query "properties.configuration.ingress.fqdn" -o tsv
  echo ""
  echo "Posledních 50 řádků logu:"
  az containerapp logs show -g "$RG" -n "$MZV_APP" --tail 50 --follow false 2>/dev/null || echo "Nelze načíst logy"
fi

echo ""
echo "📦 CONTAINER APPS - STC Service"
echo "—————————————————————————————"
STC_APP=$(az containerapp list -g "$RG" --query "[?contains(name, 'stc')] | [0].name" -o tsv 2>/dev/null)
if [ -z "$STC_APP" ]; then
  echo "❌ Nenalezena STC aplikace"
else
  echo "✅ Aplikace: $STC_APP"
fi

echo ""
echo "🗄️  SQL DATABASE"
echo "—————————————————————————————"
SQL_SERVER=$(az sql server list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
if [ -z "$SQL_SERVER" ]; then
  echo "❌ SQL Server nenalezen"
else
  echo "✅ Server: $SQL_SERVER"
  echo "FQDN: ${SQL_SERVER}.database.windows.net"
  SQL_DB=$(az sql db list -g "$RG" -s "$SQL_SERVER" --query "[0].name" -o tsv 2>/dev/null)
  echo "Database: $SQL_DB"
fi

echo ""
echo "🔑 KEY VAULT"
echo "—————————————————————————————"
KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
if [ -z "$KV" ]; then
  echo "❌ Key Vault nenalezen"
else
  echo "✅ Key Vault: $KV"
  echo ""
  echo "Secrets:"
  az keyvault secret list --vault-name "$KV" --query "[].name" -o tsv 2>/dev/null || echo "Nelze přečíst secrets"
fi

echo ""
echo "🚌 SERVICE BUS"
echo "—————————————————————————————"
SB=$(az servicebus namespace list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
if [ -z "$SB" ]; then
  echo "❌ Service Bus nenalezen"
else
  echo "✅ Namespace: $SB"
fi

echo ""
echo "🔐 API MANAGEMENT"
echo "—————————————————————————————"
APIM=$(az apim list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
if [ -z "$APIM" ]; then
  echo "❌ API Management nenalezen"
else
  echo "✅ APIM: $APIM"
  echo "Gateway URL: https://${APIM}.azure-api.net"
fi

echo ""
echo "═══════════════════════════════════════════════"
