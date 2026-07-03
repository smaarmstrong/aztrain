# Author Bicep for an Azure Files share with a quota

The finance department wants a lift-and-shift SMB file share for a legacy app,
capped at 100 GiB so it can't run away with cost. Provision it as code.

Write `main.bicep` in your workspace.

Requirements — graded on the **compiled ARM template**, so any Bicep style
(nested resources, the `parent:` property, or `/` names) that produces the
right result passes:

1. A string parameter `storageAccountName` — the account's name comes from it.
2. A string parameter `location` **defaulting to the resource group's
   location**.
3. A `Microsoft.Storage/storageAccounts` resource: kind `StorageV2`,
   SKU `Standard_LRS`.
4. A file service resource
   (`Microsoft.Storage/storageAccounts/fileServices`) named `default`.
5. A share resource
   (`Microsoft.Storage/storageAccounts/fileServices/shares`) named `finance`
   with a **`shareQuota` of `100`** (GiB).

File share reference:
https://learn.microsoft.com/azure/storage/files/storage-how-to-create-file-share

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/storage/05-bicep-files-share/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
