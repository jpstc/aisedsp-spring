# Ověření nasazení AISEDSP-Spring přes Azure Portal

Tento průvodce vám pomůže ověřit, že všechny komponenty nasazené přes ARM template fungují správně.

---

## ✅ Část 1: Ověření nasazených prostředků

### 1.1 Navigace na Resource Group

1. Jděte na [Azure Portal](https://portal.azure.com)
2. V hledacím poli vyhledejte **Resource groups**
3. Najděte svou resource group (např. **aisedsp-spring-rg**)
4. Klikněte na ni

### 1.2 Kontrolní seznam prostředků

V resource group byste měli vidět následující prostředky (✅):

| Prostředek | Typ | Status |
|-----------|------|--------|
| **kv-aisedsp-...** | Key Vault | ✅ Provided |
| **sql-aisedsp-...** | SQL Server | ✅ Online |
| **db-aisedsp** | SQL Database | ✅ Online |
| **sb-aisedsp-...** | Service Bus | ✅ Active |
| **log-aisedsp-...** | Log Analytics Workspace | ✅ Provided |
| **aisedsp-spring-...** | Container Apps Environment | ✅ Provisioned |
| **mzv-service** | Container App | ✅ Running |
| **stc-cdbp** | Container App | ✅ Running |
| **apim-aisedsp-...** | API Management | ✅ Created |

**Pokud něco chybí**: Jděte na **Deployments** a klikněte na poslední deployment, abyste viděli chyby.

---

## 1.3 Ověření a nastavení Key Vault

1. V resource group klikněte na **kv-aisedsp-...**
2. V levém menu: **Secrets**
3. **Pokud nejsou vidět žádné sekrety** - musíte je vytvořit ručně:

⚠️ **Pokud dostanete chybu "RBAC - operation is not allowed"**:
- Viz [KEYVAULT_RBAC_FIX.md](KEYVAULT_RBAC_FIX.md) pro řešení
- Stručně: Key Vault > Access Control (IAM) > Add role assignment > Key Vault Administrator

### 3a: Vytvoření SQL Connection String sekretu

1. Klikněte **+ Generate/Import**
2. Vyplňte:
   - **Name**: `sql-connection-string`
   - **Value**: 
   ```
   Server=tcp:sql-aisedsp-wl7fntssfos4a.database.windows.net,1433;Initial Catalog=db-aisedsp;Persist Security Info=False;User ID=sqladmin;Password=ChangeMe-12345!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
   ```
   (Nahraďte `sql-aisedsp-XXXX` skutečným SQL Server jménem z vaší resource group)
3. Klikněte **Create**

### 3b: Vytvoření Service Bus Connection String sekretu

1. Nejdřív ziskejte Service Bus connection string:
   - Jděte na **sb-aisedsp-...** (Service Bus)
   - V levém menu: **Shared access policies** > **RootManageSharedAccessKey**
   - Zkopírujte **Primary Connection String**

2. Zpět v Key Vault klikněte **+ Generate/Import**
3. Vyplňte:
   - **Name**: `servicebus-connection-string`
   - **Value**: Vložte zkopírovaný connection string
4. Klikněte **Create**

**Úspěšný výsledek**:
   - ✅ V Key Vault > **Secrets** vidíte:
     - `sql-connection-string`
     - `servicebus-connection-string`

---

## 1.4 Ověření SQL Database a inicializace

1. V resource group klikněte na **sql-aisedsp-...** (SQL Server)
2. Zkontrolujte v levém menu:

### Databases
- ✅ Měla by existovat databáze `db-aisedsp`

**Status databáze**:
- ✅ **Online** - normální stav
- ⚠️ **Paused** - databáze je pozastavena (auto-pause po 60 minut nečinnosti)
  - To je normální! Databáze se automaticky obnoví, když ji prvně přistupujete
  - **Abyste ji obnovili**: Jděte na **Query Editor** (viz sekce 1.4) - Query Editor ji automaticky obnoví
  - Počkejte 30-60 sekund, než se obnoví

### Firewalls a virtuální sítě
1. Jděte na **Firewalls and virtual networks**
2. Ověřte:
   - ✅ **Allow Azure services and resources to access this server**: **ON**
   - ✅ Vaše IP adresa je přidána (pokud chcete přístup z domácí sítě)

**Pokud Connection Failed**: 
- Pokud je databáze v "Paused" stavu, je to normální - obnoví se při prvním přístupu
- Zkuste stránku obnovit nebo počkejte 1-2 minuty

### Vytvoření tabulek (pokud neexistují)

1. V SQL Database jděte: **Query Editor** (Preview)
   - ⚠️ Pokud je databáze v "Paused" stavu, Query Editor ji automaticky obnoví
   - Počkejte 30-60 sekund, až se databáze obnoví
2. Přihlaste se: `sqladmin` / `ChangeMe-12345!`
3. Spusťte schema creation:

```sql
-- Vytvoření tabulky Document
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Document')
CREATE TABLE [dbo].[Document] (
  [id] INT IDENTITY(1,1) PRIMARY KEY,
  [title] NVARCHAR(MAX) NOT NULL,
  [status] NVARCHAR(50) DEFAULT 'NEW',
  [createdAt] DATETIME DEFAULT GETUTCDATE()
);

-- Vytvoření tabulky StcEvent
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'StcEvent')
CREATE TABLE [dbo].[StcEvent] (
  [id] INT IDENTITY(1,1) PRIMARY KEY,
  [documentId] INT,
  [eventType] NVARCHAR(50),
  [status] NVARCHAR(50),
  [createdAt] DATETIME DEFAULT GETUTCDATE()
);
```

4. Klikněte **Run** - měla by skončit bez chyby

---

## 1.5 Ověření Service Bus

1. V resource group klikněte na **sb-aisedsp-...**
2. V levém menu klikněte **Queues**
3. Měla by existovat fronta: ✅ **status-events**
4. Klikněte na **status-events** a zkontrolujte:
   - **Active messages**: 0 (pokud nejsou zpracovávány)
   - **Status**: ✅ Active

---

## 1.6 Ověření a nastavení Container Apps

### MZV Service

1. V resource group najděte **mzv-service** (Container App)
2. Zkontrolujte hlavní stránku:
   - **Status**: ✅ Running (pokud je šedé/deleting, počkejte)
   - **Application URL**: `https://mzv-service.......azurecontainerapps.io` (zkopírujte)

3. V levém menu **Containers**:
   - ✅ Image: `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` (nebo vaše image)
   - ✅ CPU: `0.5`
   - ✅ Memory: `1Gi`

4. **DŮLEŽITÉ**: Nastavení environment variables
   - Klikněte na **Container** v editoru
   - Pod **Environment variables** by měly být:
     - `SQL_CONN`: Měla by být vaše SQL connection string (TEĎ NASTAVUJE NA "TO_BE_SET_IN_PORTAL")
     - `SB_CONN`: Měla by být vaše Service Bus connection string
     - `SB_TOPIC`: `doc-status`

   **Pokud chybí nebo jsou na "TO_BE_SET_IN_PORTAL"**:
   
   a) Klikněte **Edit and deploy** > **Edit container**
   
   b) Pod **Environment variables** klikněte **+ Add** pro každou:
   
   | Variable | Hodnota |
   |----------|---------|
   | `SQL_CONN` | Zkopírujte z Key Vault > `sql-connection-string` |
   | `SB_CONN` | Zkopírujte z Key Vault > `servicebus-connection-string` |
   | `SB_TOPIC` | `doc-status` |
   
   c) Klikněte **Save** > **Deploy**

### STC Service

1. V resource group najděte **stc-cdbp** (Container App)
2. Zkontrolujte stejně jako MZV (viz výše)
3. **Environment variables** by měly mít navíc:
   - `SB_SUB`: `stc-cdbp` (subscription name)

4. Nastavte stejným způsobem jako MZV

---

## ✅ Část 2: Testování API

### 2.1 Základní zdravotní test (Health Check)

1. Otevřete si v novém tabu URL aplikace MZV:
   ```
   https://mzv-service.......azurecontainerapps.io
   ```
   
2. Měli byste vidět **Welcome message** s containerem (modrá hlášková aplikace)
   - ✅ Pokud ano, aplikace běží
   - ❌ Pokud vidíte chybu 502/503, aplikace se bootuje (počkejte 30 sekund)

3. Stejný test pro STC:
   ```
   https://stc-cdbp.......azurecontainerapps.io
   ```

### 2.2 Testování API dokumentů (cURL v terminálu)

Pokud máte v devkontejneru přístup (např. VS Code terminál), zkuste:

```bash
# Nahraďte <MZV_URL> skutečným URL z Container App
MZV_URL="https://mzv-service.......azurecontainerapps.io"

# HEALTH CHECK
curl -s "$MZV_URL" | head -20

# CREATE - Nový dokument (POST)
curl -X POST "$MZV_URL/api/documents" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Testovací dokument",
    "status": "NEW"
  }' | jq .

# READ - Načtěte dokument (GET)
curl "$MZV_URL/api/documents/1" | jq .

# UPDATE - Aktualizujte (PUT)
curl -X PUT "$MZV_URL/api/documents/1" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Aktualizovaný dokument",
    "status": "PROCESSED"
  }' | jq .

# DELETE - Smažte (DELETE)
curl -X DELETE "$MZV_URL/api/documents/1"
```

**Očekávané odpovědi**:
- ✅ POST: `{"id": 1, "title": "...", "status": "NEW"}`
- ✅ GET: Vrátí dokument s stejným ID
- ✅ PUT: Vrátí aktualizovaný dokument
- ✅ DELETE: HTTP 204 No Content

---

## 2.3 Testování přes Postman (alternativa)

Pokud máte Postman:

1. Importujte si kolekci:
   ```json
   {
     "info": {"name": "AISEDSP API Tests"},
     "item": [
       {
         "name": "Health Check",
         "request": {
           "method": "GET",
           "url": "{{BASE_URL}}/"
         }
       },
       {
         "name": "Create Document",
         "request": {
           "method": "POST",
           "url": "{{BASE_URL}}/api/documents",
           "body": {
             "mode": "raw",
             "raw": "{\"title\": \"Test\", \"status\": \"NEW\"}"
           }
         }
       }
     ]
   }
   ```

2. Nastavte proměnnou: `BASE_URL` = `https://mzv-service.......azurecontainerapps.io`

---

## ✅ Část 3: Ověření databáze (SQL)

### 3.1 Připojení přes Azure Portal

1. Jděte na SQL Database: **db-aisedsp**
2. V levém menu klikněte **Query Editor** (Preview)
3. Přihlaste se:
   - **Login**: `sqladmin`
   - **Password**: `ChangeMe-12345!` (výchozí z ARM template)

⚠️ **Pokud neznáte heslo**: Viz [SQL_PASSWORD_RESET.md](SQL_PASSWORD_RESET.md)

4. Spusťte query:

```sql
-- Kontrola tabulek
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'dbo';

-- Kontrola dat v dokumentech (pokud existuje)
SELECT * FROM [dbo].[Document];

-- Kontrola statusů (pokud existuje)
SELECT * FROM [dbo].[StcEvent];
```

**Očekávaný výsledek**:
- ✅ Tabulky: `Document`, `StcEvent` (nebo vaše schéma)
- ✅ Pokud jste poslali API requesty, měli byste vidět data

### 3.2 Připojení z vašeho počítače (SQL Server Management Studio / DBeaver)

Pokud chcete připojit se z locálního nástroje:

1. Jděte na SQL Server > **Firewalls and virtual networks**
2. Klikněte **Add your IP address** (zjistíte si svou IP)
3. Poté se připojte:
   - **Server**: `sql-aisedsp-xxxx.database.windows.net`
   - **Login**: `sqladmin`
   - **Password**: `ChangeMe-12345!`
   - **Database**: `db-aisedsp`

---

## ✅ Část 4: Ověření Service Bus (Message Flow)

### 4.1 Control Plane - Kontrola fronty

1. Jděte na Service Bus: **sb-aisedsp-...**
2. V levém menu: **Queues** > **status-events**
3. Zkontrolujte metrika:
   - **Active messages**: Počet zpráv, které čekají
   - **Dead letter messages**: Pokud jsou nějaké, je problém se zpracováním

### 4.2 Odeslání testovací zprávy (SQL2Services)

Pokud váš STC listener slouchá na Service Bus:

1. Jděte na **Topics** (pokud Topic existuje)
2. Klikněte na **Subscriptions** (měla by být `stc-cdbp`)
3. Zkontrolujte **Messages** - měl by vidět příchozí zprávy

---

## ✅ Část 5: Ověření API Management

### 5.1 Základní informace

1. Jděte na **apim-aisedsp-...** v resource group
2. V levém menu: **Overview**
3. Zkopírujte **Gateway URL**: `https://apim-aisedsp-...azure-api.net`

### 5.2 Testování APIM Gateway

1. Otevřete Gateway URL v prohlížeči a připojte `/mzv`:
   ```
   https://apim-aisedsp-...azure-api.net/mzv
   ```
   - ✅ Měla by předat požadavek na MZV backend

2. Testujte přesměrování:
   ```bash
   curl "https://apim-aisedsp-...azure-api.net/mzv/api/documents"
   ```

### 5.3 Kontrola backend poolů

1. V APIM menu: **Backend pools**
2. Zkontrolujte, že existují:
   - ✅ `mzv-backend` → `https://mzv-service.......azurecontainerapps.io`
   - ✅ `stc-backend` → `https://stc-cdbp.......azurecontainerapps.io`

### 5.4 Kontrola API definic

1. V APIM menu: **APIs**
2. Měly by existovat API:
   - ✅ `MZV API` → Backend pool: mzv-backend
   - ✅ `STC API` → Backend pool: stc-backend

---

## 🔍 Část 6: Monitoring a Logy

### 6.1 Container App Logy (MZV)

1. Jděte na **mzv-service** (Container App)
2. V levém menu: **Monitoring** > **Logs**
3. Spusťte query:

```kusto
ContainerAppConsoleLogs
| where ContainerAppName == "mzv-service"
| order by TimeGenerated desc
| take 100
```

**Hledejte**:
- ✅ `Started on port`
- ✅ `Spring Boot started successfully`
- ❌ Pokud vidíte `ERROR` nebo `EXCEPTION`, aplikace se nebootuje

### 6.2 Live Tail (Real-time logy)

1. V Container App: **Monitoring** > **Live Metrics**
2. Uvidíte live CPU, Memory, Requests
3. Když pošlete API request, měl byste vidět v real-time

### 6.3 Application Insights (event tracking)

Pokud je Application Insights nainstalován:

1. Jděte na Log Analytics Workspace: **log-aisedsp-...**
2. Klikněte: **Logs** (nebo otevřete v novém tabu)
3. Spusťte query:

```kusto
requests
| where name contains "api/documents"
| order by timestamp desc
| take 100
```

---

## ❌ Troubleshooting

### Chyba: Aplikace vrací HTTP 502 Bad Gateway

**Příčiny**:
1. Aplikace se ještě bootuje (trvá 30-60 sekund)
2. Chybný Docker image
3. Chybné environment variables

**Řešení**:
1. Počkejte 2-3 minuty a zkuste znovu
2. V Container App > **Containers** zkontrolujte **Image** 
3. V **Environment variables** ověřte:
   - `SPRING_DATASOURCE_URL` (správný SQL server)
   - `SPRING_DATASOURCE_USERNAME` (sqladmin)
4. Zkontrolujte logy (Monitoring > Logs)

### Chyba: SQL Connection Failed

**Příčiny**:
1. SQL Server je stále inicializován
2. Firewall nepovoluje Azure Services
3. Connection string je nesprávný
4. Databáze je v "Paused" stavu (auto-pause po 60 minut nečinnosti)

**Řešení**:
1. Počkejte 2-3 minuty
2. V SQL Server > **Firewalls and virtual networks** ověřte:
   - ✅ **Allow Azure services and resources**: ON
3. V Key Vault > **Secrets** zkontrolujte `sql-connection-string`
4. Pokud je DB v Paused stavu:
   - **Nejjednodušší řešení**: Jděte na **Query Editor** (sekce 1.4)
   - Query Editor databázi automaticky obnoví
   - Počkejte 30-60 sekund, až se obnoví
   - Pokud existuje tlačítko **Resume** v DB overview, klikněte na něj

### Chyba: API management (APIM) vrací 404

**Příčiny**:
1. Backend pool není nakonfigurován
2. API route není namapována

**Řešení**:
1. V APIM > **Backend pools** přidejte backend
2. V APIM > **APIs** > **Settings** ověřte:
   - Web service URL je správný
   - Service URL path je správný (např. `/mzv`)

### Chyba: Service Bus nenachází zprávy

**Příčiny**:
1. Nikdo neposílá zprávy na topic
2. Subscription filtry zablokují zprávy

**Řešení**:
1. Ověřte, že MZV aplikace posílá zprávy
2. V Service Bus > **Subscriptions** > **Filters** zkontrolujte kork
3. Pokud nejsou filtery, měl by odebírat všechny zprávy

---

## ✅ Kontrolní seznam - Úspěšné nasazení

Pokud máte všechno ✅, nasazení je úspěšné:

- [ ] Všechny prostředky vidím v Resource Group
- [ ] Key Vault má sekret `sql-connection-string`
- [ ] SQL Database je `Online`
- [ ] Obě Container Apps (`mzv-service` a `stc-cdbp`) mají status `Running`
- [ ] Health check vrací odpověď (není 502/503)
- [ ] POST API request vytvoří dokument
- [ ] GET API request vrátí dokument
- [ ] Logy v Monitoring neukazují chyby
- [ ] API Management gateway je dostupný
- [ ] Service Bus Queue `status-events` je aktivní

---

## 📞 Co dělat, pokud něco selhalo?

1. **Přečtěte si logy**: Container App > Monitoring > Logs
2. **Restartujte container**: Container App > **Restart**
3. **Zkontrolujte firewall**: SQL Server > Firewalls and virtual networks
4. **Zkontrolujte environment variables**: Container App > Containers
5. **Počkejte 5 minut**: Nové nasazení chvíli trvá
6. **Vytvořte nové Resource Group**: Pokud nic nefunguje, vymažte vše a nasaďte znovu

---

## Další kroky pro PROD

Až bude vše pracovat:

1. **Nahraďte placeholder images** na skutečné Docker images (z ACR)
2. **Nakonfigurujte APIM policies** (JWT, rate limiting) z `apim-policies/`
3. **Nastavte monitoring**: Application Insights, Alerts
4. **Migrace na Managed Identity**: Místo SQL passwords
5. **SSL/TLS**: Custom domain + certificate
