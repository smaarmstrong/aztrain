# Author Bicep for a private blob container on a Cool-tier account

An analytics team needs a place to drop infrequently-read export files. You
will provision the account, its blob service, and a single container — all as
code so nothing is clicked in the portal and no container is ever accidentally
left public.

Write `main.bicep` in your workspace.

Requirements — graded on the **compiled ARM template**, so any Bicep style
(nested resources, the `parent:` property, or `/` names) that produces the
right result passes:

1. A string parameter `storageAccountName` — the account's name comes from it.
2. A string parameter `location` **defaulting to the resource group's
   location**.
3. A `Microsoft.Storage/storageAccounts` resource:
   - kind `StorageV2`, SKU `Standard_LRS`
   - default **`accessTier`** of **`Cool`** (infrequently accessed data).
4. A blob service resource
   (`Microsoft.Storage/storageAccounts/blobServices`) named `default`.
5. A container resource
   (`Microsoft.Storage/storageAccounts/blobServices/containers`) named
   `exports`, with **`publicAccess`** set to **`None`**.

Container / access-tier reference:
https://learn.microsoft.com/azure/storage/blobs/blob-containers-portal

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/storage/04-bicep-blob-container/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
