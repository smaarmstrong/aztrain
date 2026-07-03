# Author Bicep that disables shared-key access, forcing Entra auth

Account keys and the SAS tokens derived from them are long-lived bearer
secrets: leak one and an attacker has your data. Your security baseline now
mandates that new storage accounts **reject shared-key (and SAS) access
entirely** and require callers to authenticate with Microsoft Entra ID, and
that Entra be the default authorization method in the portal.

Write `main.bicep` in your workspace declaring such an account.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `storageAccountName` — the account's name comes from it.
2. A string parameter `location` **defaulting to the resource group's
   location**.
3. Exactly one `Microsoft.Storage/storageAccounts` resource: kind `StorageV2`,
   SKU `Standard_LRS`, with:
   - **`allowSharedKeyAccess`** set to **`false`** (no account-key / SAS auth).
   - **`defaultToOAuthAuthentication`** set to **`true`** (Entra is the default
     authorization method).

Reference — prevent Shared Key authorization:
https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/storage/06-disable-shared-key/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
