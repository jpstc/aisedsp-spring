# Návod na nasazení přes Azure Portal

Tento návod vás provede ruční konfigurací všech potřebných Azure prostředků bez použití CLI/skriptů.

## Prerequisity

- Azure účet s aktivním předplatným
- Přístup k Azure Portal (https://portal.azure.com)

---

## Krok 1: Vytvoření Resource Group

1. Jděte na **Azure Portal** > **Resource groups**
2. Klikněte na **+ Create**
3. Vyplňte:
   - **Subscription**: Vyberte vaše předplatné
   - **Resource group name**: `aisedsp-spring-rg`
   - **Region**: `West Europe` (nebo vaše preferovaná region)
4. Klikněte **Review + Create** > **Create**

---

## Krok 2: Vytvoření Key Vault

1. V Resource Group jděte na **+ Create**
2. Hledejte **Key Vault** a vyberte
3. Na kartě **Basics** vyplňte:
   - **Resource group**: `aisedsp-spring-rg`
   - **Key Vault name**: `kv-aisedsp-${RANDOM}` (musí být unikátní, např. `kv-aisedsp-12345`)
   - **Region**: Stejná jako Resource Group
   - **Pricing tier**: `Standard`
4. **Next: Access policy**
5. Klikněte **+ Add Access Policy**:
   - **Configure from template**: `Secret Management`
   - **Select principal**: Vyberte svého uživatele nebo spravovanou identitu
6. **Review + Create** > **Create**

---

## Krok 3: Vytvoření SQL Database

1. V Resource Group jděte na **+ Create**
2. Hledejte **SQL Database** a vyberte
3. Na kartě **Basics** vyplňte:
   - **Resource group**: `aisedsp-spring-rg`
   - **Database name**: `aisedsp-db`
   - **Server**: Klikněte **Create new**
     - **Server name**: `aisedsp-server` (musí být unikátní)
     - **Region**: Stejná jako Resource Group
     - **Authentication method**: `Use SQL authentication`
     - **Server admin login**: `sqladmin`
     - **Password**: `ChangeMe-12345!` (změňte později!)
     - **Confirm password**: `ChangeMe-12345!`
   - Klikněte **OK**
   - **Compute + storage**: `General Purpose` (výchozí)
4. **Next: Networking**
5. **Connectivity method**: `Public endpoint`
6. **Allow Azure services and resources to access this server**: `Yes`
7. **Other firewall rules**: Přidejte vaši IP adresu (volitelné, pro přístup z vaší sítě)
8. **Review + Create** > **Create**

---

## Krok 4: Uložení SQL Connection String do Key Vault

1. Jděte do SQL Serveru a zkopírujte **Connection string** (ADO.NET)
2. Otevřete Key Vault z kroku 2
3. V levém menu klikněte **Secrets** > **+ Generate/Import**
4. Vyplňte:
   - **Name**: `sql-connection-string`
   - **Value**: `Server=tcp:aisedsp-server.database.windows.net,1433;Initial Catalog=aisedsp-db;Persist Security Info=False;User ID=sqladmin;Password=ChangeMe-12345!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;`
5. Klikněte **Create**

---

## Krok 5: Vytvoření Service Bus

1. V Resource Group jděte na **+ Create**
2. Hledejte **Service Bus** a vyberte
3. Na kartě **Basics** vyplňte:
   - **Resource group**: `aisedsp-spring-rg`
   - **Namespace name**: `sb-aisedsp-${RANDOM}` (např. `sb-aisedsp-12345`)
   - **Region**: Stejná jako Resource Group
   - **Pricing tier**: `Standard`
4. **Review + Create** > **Create**
5. Po vytvoření:
   - Jděte do **Queues** > **+ Queue**
   - **Name**: `status-events`
   - Klikněte **Create**

---

## Krok 6: Uložení Service Bus Connection String do Key Vault

1. Jděte do Service Bus Namespace > **Shared access policies**
2. Klikněte **RootManageSharedAccessKey** a zkopírujte **Primary Connection String**
3. Otevřete Key Vault z kroku 2
4. **Secrets** > **+ Generate/Import**
5. Vyplňte:
   - **Name**: `servicebus-connection-string`
   - **Value**: Vložte zkopírovaný connection string
6. Klikněte **Create**

---

## Krok 7: Vytvoření Container Apps Environment

1. V Resource Group jděte na **+ Create**
2. Hledejte **Container App** a vyberte (vytvořit environment)
3. Na kartě **Basics** vyplňte:
   - **Resource group**: `aisedsp-spring-rg`
   - **Container App name**: `aca-aisedsp`
   - **Region**: Stejná jako Resource Group
4. **Container**:
   - **Image**: `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`
   - **Name**: `mzv-container`
   - **CPU**: `0.5`
   - **Memory**: `1Gi`
5. **Ingress**:
   - **Ingress**: `Enabled`
   - **Ingress traffic**: `HTTP`
   - **Target port**: `80`
6. **Review + Create** > **Create**

---

## Krok 8: Vytvoření dalšího Container App pro STC

1. Zopakujte krok 7, ale s:
   - **Container App name**: `aca-stc`
   - **Image**: `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`
   - **Name**: `stc-container`

---

## Krok 9: Vytvoření API Management (volitelné)

1. V Resource Group jděte na **+ Create**
2. Hledejte **API Management** a vyberte
3. Na kartě **Basics** vyplňte:
   - **Resource group**: `aisedsp-spring-rg`
   - **Instance name**: `apim-aisedsp`
   - **Organization name**: `AISEDSP Organization`
   - **Administrator email**: Vaš email
   - **Pricing tier**: `Developer` (nejlevnější volba)
4. **Review + Create** > **Create**
   - ⚠️ **Poznámka**: Nasazení může trvat 15-20 minut

---

## Krok 10: Ověření nasazení

1. Jděte na **Resource Groups** > `aisedsp-spring-rg`
2. Měli byste vidět:
   - ✓ Key Vault
   - ✓ SQL Server + Database
   - ✓ Service Bus Namespace
   - ✓ Container Apps (2x)
   - ✓ API Management (pokud jste vytvořili)

3. Otestujte připojení:
   - **Container Apps**: Zkopírujte Application URL a otevřete v prohlížeči
   - **API Management**: Zkopírujte Gateway URL a otestujte Swagger UI

---

## Krok 11: Post-Provision Konfigace (ruční)

Některé kroky z `postprovision.sh` je třeba provést ručně:

### 11a: Deploye Java aplikace do Container Apps

1. Vytvořte image Java aplikace (nebo použijte existující z Container Registry):
   ```
   docker build -t yourregistry.azurecr.io/mzv-service:latest .
   docker push yourregistry.azurecr.io/mzv-service:latest
   ```

2. V Container App (MZV) > **Settings** > **Containers**
3. Aktualizujte **Image** na vaši image URL
4. Přidejte **Environment variables**:
   - `SPRING_DATASOURCE_URL`: `jdbc:sqlserver://aisedsp-server.database.windows.net:1433;database=aisedsp-db;authenticate=ActiveDirectoryManagedIdentity;`
   - `SPRING_DATASOURCE_USERNAME`: Vaš SQL login
   - `SPRING_DATASOURCE_PASSWORD`: Vaše SQL password

### 11b: Nakonfigurujte APIM Backend

1. V APIM > **Backend pools** > **+ Add**
2. Vyplňte:
   - **Name**: `mzv-backend`
   - **Type**: `HTTP`
   - **URL**: `https://aca-aisedsp.yellowwater-abc123.eastus.azurecontainerapps.io/`
3. Zopakujte pro STC

### 11c: Vytvořte API v APIM

1. V APIM > **APIs** > **+ Add API**
2. **Blank API**
3. Vyplňte:
   - **Name**: `MZV API`
   - **Display name**: `MZV Service`
   - **Web service URL**: URL z MZV Container App

---

## Troubleshooting

### Chyba: "Namespace name must be globally unique"
- Změní název Service Bus a SQL Server na něco Unikalního (např. přidejte čas: `sb-aisedsp-$(date +%s)`)

### Chyba: "Cannot create resource - subscription quota"
- Ověřte, že máte dostatek disponibilního limitu ve vašem předplatném

### Chyba: "Connection refused" z Container App
- Ověřte, že firewall SQL Serveru umožňuje Azure Services
- V SQL Server > **Networking** > **Allow Azure services and resources**: **ON**

### API Management se nasazuje moc dlouho
- Je to normální, APIM nasazení trvá 15-20 minut, počkejte

---

## Cleanup (pokud chcete odstranit vše)

1. Jděte na Azure Portal > **Resource Groups**
2. Vyberte `aisedsp-spring-rg`
3. Klikněte **Delete resource group**
4. Potvrďte zadáním názvu Resource Group a klikněte **Delete**

---

## Další kroky

- Aktualizujte Docker image v Container Apps na vaši Java aplikaci
- Nakonfigurujte APIM policies (JWT, rate limiting atd.) z `apim-policies/`
- Otestujte MZV → STC data flow přes Service Bus
