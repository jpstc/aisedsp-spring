#!/bin/bash
# Test API - uložení a načtení dokumentu
# Spustit: bash infra/scripts/test-api.sh <app-url>

APP_URL=${1:-"http://localhost:8081"}

echo "═══════════════════════════════════════════════"
echo "TEST API - Uložení a načtení dokumentu"
echo "═══════════════════════════════════════════════"
echo ""
echo "URL: $APP_URL"
echo ""

# 1. Health Check
echo "1️⃣  HEALTH CHECK"
echo "—————————————————————————————"
echo "GET /actuator/health"
HEALTH=$(curl -s -w "\n%{http_code}" "$APP_URL/actuator/health")
HTTP_CODE=$(echo "$HEALTH" | tail -n1)
BODY=$(echo "$HEALTH" | head -n-1)
echo "Status: $HTTP_CODE"
echo "Response: $BODY"
echo ""

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Aplikace není dostupná!"
  exit 1
fi

# 2. Create Document
echo "2️⃣  VYTVOŘENÍ DOKUMENTU"
echo "—————————————————————————————"
TITLE="TestDocument-$(date +%s)"
echo "POST /api/documents"
echo "Payload: {\"title\": \"$TITLE\", \"status\": \"NEW\"}"
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APP_URL/api/documents" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"$TITLE\", \"status\": \"NEW\"}")

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
BODY=$(echo "$CREATE_RESPONSE" | head -n-1)
echo "Status: $HTTP_CODE"
echo "Response: $BODY"
echo ""

if [ "$HTTP_CODE" != "201" ]; then
  echo "❌ Zápis do DB selhal!"
  echo "Chyby k řešení:"
  echo "  - Zkontrolovat SQL Database konektivitu"
  echo "  - Zkontrolovat environment Variable SQL_CONN"
  echo "  - Zkontrolovat logy Container Apps"
  exit 1
fi

# Extract ID
DOC_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
echo "✅ Záznam vytvořen, ID: $DOC_ID"
echo ""

# 3. Read Document
echo "3️⃣  NAČTENÍ DOKUMENTU"
echo "—————————————————————————————"
echo "GET /api/documents/$DOC_ID"
READ_RESPONSE=$(curl -s -w "\n%{http_code}" "$APP_URL/api/documents/$DOC_ID")

HTTP_CODE=$(echo "$READ_RESPONSE" | tail -n1)
BODY=$(echo "$READ_RESPONSE" | head -n-1)
echo "Status: $HTTP_CODE"
echo "Response: $BODY"
echo ""

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Čtení z DB selhalo!"
  exit 1
fi

echo "✅ Záznam úspěšně načten"
echo ""

# 4. Update Document
echo "4️⃣  AKTUALIZACE DOKUMENTU"
echo "—————————————————————————————"
echo "PUT /api/documents/$DOC_ID"
UPDATE_PAYLOAD="{\"title\": \"$TITLE - UPDATED\", \"status\": \"PROCESSED\"}"
echo "Payload: $UPDATE_PAYLOAD"
UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$APP_URL/api/documents/$DOC_ID" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD")

HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -n1)
BODY=$(echo "$UPDATE_RESPONSE" | head -n-1)
echo "Status: $HTTP_CODE"
echo "Response: $BODY"
echo ""

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Aktualizace selhala!"
  exit 1
fi

echo "✅ Záznam úspěšně aktualizován"
echo ""

# 5. Delete Document
echo "5️⃣  SMAZÁNÍ DOKUMENTU"
echo "—————————————————————————————"
echo "DELETE /api/documents/$DOC_ID"
DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$APP_URL/api/documents/$DOC_ID")

HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)
echo "Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" != "204" ]; then
  echo "❌ Smazání selhalo!"
  exit 1
fi

echo "✅ Záznam úspěšně smazán"
echo ""

echo "═══════════════════════════════════════════════"
echo "✅ VŠECHNY TESTY PROŠLY!"
echo "═══════════════════════════════════════════════"
