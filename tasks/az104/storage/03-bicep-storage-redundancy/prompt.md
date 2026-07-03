# Author Bicep for a geo-zone-redundant (GZRS) storage account

The compliance team requires that the account backing your payments service
survives both a zone outage **and** a full regional outage. That is exactly
what **geo-zone-redundant storage (GZRS)** buys you: three synchronous copies
across availability zones in the primary region, plus asynchronous replication
to a paired secondary region.

Write `main.bicep` in your workspace declaring that account.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `storageAccountName` — the account's name comes from it.
2. A string parameter `location` **defaulting to the resource group's
   location**.
3. Exactly one `Microsoft.Storage/storageAccounts` resource:
   - kind `StorageV2`
   - SKU **`Standard_GZRS`** (geo-zone-redundant)
4. An output named `skuName` carrying the account's SKU name (so a pipeline can
   assert the redundancy it deployed).

Redundancy options reference:
https://learn.microsoft.com/azure/storage/common/storage-redundancy

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/storage/03-bicep-storage-redundancy/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
