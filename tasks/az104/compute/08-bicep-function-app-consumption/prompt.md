# Author Bicep for a serverless (Consumption) Function App

A lightweight event handler should run on Azure Functions with pay-per-use
billing — the Consumption plan. Write `main.bicep` (in your workspace) that a
pipeline could deploy to stand up the storage account, the Consumption plan,
and the Function App together.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `appName`, a string `storageAccountName`, and a
   string `location` **defaulting to the resource group's location**.
2. A `Microsoft.Storage/storageAccounts` resource (`StorageV2`,
   `Standard_LRS`) — Functions require a backing storage account.
3. A `Microsoft.Web/serverfarms` plan on the **Consumption** tier: SKU name
   **`Y1`**, tier **`Dynamic`**.
4. A `Microsoft.Web/sites` Function App:
   - `kind` marking it a function app (contains `functionapp`).
   - Bound to the Consumption plan via `serverFarmId`.
   - **`httpsOnly` true**.
   - `siteConfig.appSettings` including **`AzureWebJobsStorage`** and
     **`FUNCTIONS_WORKER_RUNTIME`**.

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
