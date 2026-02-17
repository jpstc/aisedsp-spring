#!/bin/bash
# Quick setup - obtain Azure App URL and run tests
# Spustit: bash infra/scripts/quick-test.sh

set -e

echo "═══════════════════════════════════════════════"
echo "QUICK TEST SETUP"
echo "═══════════════════════════════════════════════"
echo ""

# Get resource group from user
if [ -z "$1" ]; then
  echo "❓ Resource Group jméno:"
  read -r RG
  if [ -z "$RG" ]; then
    echo "❌ Resource Group jméno je povinné"
    exit 1
  fi
else
  RG="$1"
fi

echo ""
echo "🔍 Hledám aplikace v resource group: $RG"
echo ""

# Get MZV App
MZV_APP=$(az containerapp list -g "$RG" --query "[?contains(name, 'mzv')] | [0].name" -o tsv 2>/dev/null)
if [ -z "$MZV_APP" ]; then
  echo "❌ MZV aplikace nenalezena v $RG"
  exit 1
fi

echo "✅ Najdena aplikace: $MZV_APP"

# Get URL
MZV_URL=$(az containerapp show -g "$RG" -n "$MZV_APP" --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null)
if [ -z "$MZV_URL" ]; then
  echo "❌ Nelze získat URL aplikace"
  exit 1
fi

MZV_URL="https://$MZV_URL"
echo "✅ URL: $MZV_URL"
echo ""

# Check if app is running
echo "🔍 Ověřuji, že aplikace běží..."
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$MZV_URL/actuator/health")
if [ "$HEALTH" != "200" ]; then
  echo "⚠️  Aplikace není dostupná (HTTP $HEALTH)"
  echo "   Čekám 10 sekund a zkouším znovu..."
  sleep 10
  HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$MZV_URL/actuator/health")
fi

if [ "$HEALTH" = "200" ]; then
  echo "✅ Aplikace běží!"
else
  echo "❌ Aplikace není dostupná (HTTP $HEALTH)"
  echo ""
  echo "Logy:"
  az containerapp logs show -g "$RG" -n "$MZV_APP" --tail 30
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "🧪 SPOUŠTĚNÍ TESTŮ"
echo "═══════════════════════════════════════════════"
echo ""

bash infra/scripts/test-api.sh "$MZV_URL"
