# Řešení: RBAC Chyba v Key Vault

**Chyba**: "The operation is not allowed by RBAC"

Příčina: Váš uživatel/spravovaná identita nemá oprávnění na Key Vault.

---

## 🔧 Řešení: Přidání oprávnění

### Krok 1: Otevřete Key Vault

1. Jděte na Azure Portal > **Resource Groups** > vaše RG
2. Najděte **kv-aisedsp-...** a klikněte na něj

### Krok 2: Přidání Role Assignment

1. V levém menu: **Access Control (IAM)**
2. Klikněte: **+ Add** > **Add role assignment**
3. Vyplňte:
   - **Role**: `Key Vault Administrator` (nebo `Key Vault Secrets Officer`)
   - **Assign access to**: `User, group, or service principal`
   - **Members**: Klikněte **Select members** a vyberte:
     - Váš uživatel (email z Azure AD)
     - NEBO managed identity z Container Apps (pokud chcete automatizovat)

### Kroku 3: Uložení

- Klikněte **Review + assign** > **Assign**

### Krok 4: Počkejte 2-3 minuty

**DŮLEŽITÉ**: Role assignment se aplikuje s latencí. Počkejte několik minut, než zkusíte znovu.

---

## Alternativa: Změna Access Policy (starší přístup)

Pokud výše uvedené nefunguje, zkuste alternativu:

1. V Key Vault menu: **Access policies** (ne IAM)
2. Klikněte: **+ Create**
3. **Permissions**:
   - **Secret permissions**: `Get`, `List`, `Set`, `Delete`
4. **Principal**: Vyberte svého uživatele
5. Klikněte **Create**

---

## Po přidání oprávnění

1. **Počkejte 2-3 minuty** (role se aplikují s latencí)
2. **Obnovte prohlížeč** (F5 nebo Ctrl+R)
3. **Zkuste znovu vytvořit secret** (sekce 1.3a v VERIFICATION_GUIDE.md)

Pokud pořád nejde:
- Odhlaste se z Azure Portal a přihlaste se znovu
- Nebo zkuste inkognito mód (Control+Shift+N)

---

## Pro Container Apps (spravovaná identita)

Pokud chcete, aby se Container Apps mohly připojit k Key Vault automaticky:

1. **Vytvořte spravovanou identitu** v Container App:
   - Container App > **Identity** > **System assigned** > **ON**

2. **Přidejte role assignment** v Key Vault (Access Control):
   - Role: `Key Vault Secrets User`
   - Principal: Vyberte spravovanou identitu Container App

3. **Aktualizujte environment variables** v Container App na Key Vault reference:
   ```
   @Microsoft.KeyVault(VaultName=kv-aisedsp-XXXX;SecretName=sql-connection-string)
   ```

---

## ⚡ Rychlý workaround (pokud máte přístup Admin)

Pokud jste **Owner** subscription:

1. Jděte na Key Vault > **Access Control (IAM)**
2. Klikněte: **+ Add** > **Add role assignment**
3. **Role**: `Key Vault Administrator`
4. **Members**: Vyberte sebe
5. **Assign**

Poté zkuste znovu.
