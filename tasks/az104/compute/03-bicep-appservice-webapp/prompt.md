# Author Bicep for a Linux App Service plan and HTTPS-only web app

A small internal Python API should run on App Service. Write `main.bicep` (in
your workspace) that a pipeline could deploy to stand up the plan and the web
app together, on the cheapest paid Linux tier, locked to HTTPS.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `appName` and a string `location` **defaulting to the
   resource group's location**.
2. A `Microsoft.Web/serverfarms` (App Service plan) resource:
   - SKU name **`B1`** (Basic), and a Linux plan (`reserved` true).
3. A `Microsoft.Web/sites` (web app) resource:
   - Bound to the plan above via `serverFarmId`.
   - **`httpsOnly` true**.
   - A `siteConfig` with a **`linuxFxVersion`** runtime string set to a Python
     runtime (`PYTHON|3.12`).

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
