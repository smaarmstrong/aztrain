# Author Bicep for a locked-down StorageV2 account

Your team deploys everything through IaC. Write `main.bicep` (in your
workspace) that a pipeline could deploy into any resource group to get a
general-purpose v2 storage account that passes a security review.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `storageAccountName` (no default needed) — the account's
   name must come from this parameter.
2. A string parameter `location` **defaulting to the resource group's
   location**, used as the account's location.
3. Exactly one `Microsoft.Storage/storageAccounts` resource:
   - kind `StorageV2`, SKU `Standard_LRS`
   - minimum TLS version `TLS1_2`
   - blob public access **disabled**
   - HTTPS-only traffic **enforced**
4. An output named `blobEndpoint` carrying the account's primary blob
   endpoint.

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/storage/01-bicep-storage-account/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
