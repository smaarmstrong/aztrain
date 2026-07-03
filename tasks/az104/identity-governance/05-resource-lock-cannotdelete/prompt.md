# Protect a storage account with a CanNotDelete lock (Bicep)

An auditor flagged that your production storage account has no delete
protection. Add a **management lock** so nobody can accidentally delete the
account, while still allowing normal read/write operations to its data.

Write `main.bicep` (in your workspace) that declares the storage account **and**
a lock scoped to it.

Requirements — graded on the **compiled ARM template**:

1. A parameter `storageAccountName` (string) — the account name comes from it.
2. One `Microsoft.Storage/storageAccounts` resource (kind `StorageV2`, SKU
   `Standard_LRS`) named from that parameter.
3. One `Microsoft.Authorization/locks` resource whose:
   - `level` is **`CanNotDelete`** (NOT `ReadOnly` — data operations must keep
     working), and
   - it is **scoped to the storage account** (declared as a child/nested lock
     of the account, or with an explicit `scope` referencing it — either form
     compiles to a lock whose name is prefixed by the account and whose type is
     the account's nested `.../providers/locks`).

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
