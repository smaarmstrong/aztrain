# Author Bicep for a hardened, RBAC-authorized Key Vault

Your platform team stores pipeline secrets, keys and certificates in Azure Key
Vault, and every vault must clear a security review before it ships. Write
`main.bicep` (in your workspace) that a pipeline could deploy into any resource
group to create a Key Vault locked down to the standard.

Requirements — graded on the **compiled ARM template**, so any Bicep style that
produces the right result passes:

1. A string parameter `keyVaultName` (no default needed) — the vault's name must
   come from this parameter.
2. A string parameter `location` **defaulting to the resource group's
   location**, used as the vault's location.
3. A string parameter `tenantId` **defaulting to the subscription's tenant**
   (`subscription().tenantId`), used as the vault's `tenantId`.
4. Exactly one `Microsoft.KeyVault/vaults` resource with these properties:
   - SKU family `A`, SKU name `standard`
   - **RBAC authorization enabled** (`enableRbacAuthorization: true`) — do NOT
     use access policies.
   - **Soft-delete enabled** with a retention of `90` days.
   - **Purge protection enabled**.
   - A `networkAcls` block whose `defaultAction` is `Deny` (network
     default-deny) and whose `bypass` is `AzureServices`.
5. An output named `vaultUri` carrying the vault's URI
   (`properties.vaultUri`).

Check your work compiles as you go:

```sh
az bicep build --file workspace/az400/security-compliance/01-keyvault-bicep/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
