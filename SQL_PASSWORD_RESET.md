# Reset SQL hesla

Pokud neznáte heslo pro SQL Server, můžete ho resetovat.

---

## Krok 1: Otevřete SQL Server

1. Jděte na Azure Portal > **Resource Groups** > vaše RG
2. Najděte **sql-aisedsp-...** (SQL Server) a klikněte na něj

---

## Krok 2: Reset Admin hesla

1. V levém menu: **Reset password**
2. Vyplňte:
   - **SQL admin login**: `sqladmin` (nebo váš login)
   - **New password**: Nastavte nové heslo (musí být silné - minimálně 8 znaků, velkého písmena, čísla, speciální znaky)
     - Příklad: `Securepass123!`
   - **Confirm password**: Zopakujte
3. Klikněte **OK**

---

## Krok 3: Poznamenejte si nové heslo

Po úspěšném resetu:
- Login: `sqladmin`
- Password: Vaše nové heslo (z kroku 2)

---

## Krok 4: Aktualizujte Key Vault sekret

1. Jděte na **Key Vault** > **Secrets**
2. Klikněte na `sql-connection-string`
3. Klikněte **New Version**
4. Nahraďte heslo v connection stringu:
   ```
   Server=tcp:sql-aisedsp-XXXX.database.windows.net,1433;Initial Catalog=db-aisedsp;Persist Security Info=False;User ID=sqladmin;Password=VasheNoveHeslo!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
   ```
5. Klikněte **Create**

---

## Krok 5: Aktualizujte Container Apps

Pokud jste už nastavili Container Apps s environment variables:

1. V **mzv-service** Container App:
   - **Edit and deploy** > **Edit container**
   - Najděte `SQL_CONN` environment variable
   - Aktualizujte na nové heslo
   - Klikněte **Save** > **Deploy**

2. Zopakujte pro **stc-cdbp** Container App

---

## Krok 6: Testujte připojení

1. Jděte na **db-aisedsp** (SQL Database)
2. V levém menu: **Query Editor**
3. Přihlaste se:
   - **Login**: `sqladmin`
   - **Password**: Vaše nové heslo
4. Pokud se přihlášení zdaří, heslo je správné ✅

---

## Výchozí heslo z ARM template

Pokud jste nasadili přes ARM template bez změny, výchozí heslo bylo:
- **Login**: `sqladmin`
- **Password**: `ChangeMe-12345!`

Zkuste nejdřív toto heslo. Pokud nefunguje, proveďte reset výše.
