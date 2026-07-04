# Enable a system-assigned managed identity on a web app

The app team wants their web app to reach Key Vault and Storage **without any
secrets in config** — that means giving the app its own identity in Microsoft
Entra ID.

Setup has created (in your `rg-aztrain-...` resource group, on the **free F1
App Service tier**) a single web app that currently has **no managed identity
at all**. Find its name with:

```sh
az webapp list -g $RG --query "[].name" -o tsv
```

## Requirement

Turn on a **system-assigned managed identity** for that web app, so that:

- The app's `identity.type` includes **`SystemAssigned`**.
- The identity has a real **`principalId`** (a service principal now exists
  for the app in Entra ID).

How you get there is up to you — portal, CLI, or redeploy. The grader only
reads the app's identity, so **any method that ends with the identity enabled
passes**.

Useful commands:

```sh
az webapp identity show -g $RG -n <app-name>
az webapp identity assign --help
```

(`$RG` is printed by `aztrain start`; it's also the only `rg-aztrain-*` group
for this task in `az group list -o table`.)
