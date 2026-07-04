# Author Bicep for a workspace-based Application Insights component

Your team wants every service to ship telemetry into Application Insights so
distributed traces, requests, and dependencies land in one place. Classic
(standalone) App Insights is retired — new components must be **workspace-based**,
sending their data to a Log Analytics workspace.

Write `main.bicep` (in your workspace) that a pipeline could deploy into any
resource group to stand up the telemetry backend.

Requirements — graded on the **compiled ARM template**, so any Bicep style that
produces the right result passes:

1. Parameters `workspaceName` and `appInsightsName` (strings), plus a `location`
   string **defaulting to the resource group's location** used for both resources.
2. Exactly one `Microsoft.OperationalInsights/workspaces` (a Log Analytics
   workspace).
3. Exactly one `Microsoft.Insights/components` (Application Insights):
   - `kind` of `web`
   - `Application_Type` of `web`
   - **workspace-based**: its `WorkspaceResourceId` must point at the Log
     Analytics workspace you declared above.
4. An output named `connectionString` carrying the component's connection
   string (the modern replacement for the instrumentation key).

Check your work compiles as you go:

```sh
az bicep build --file workspace/az400/instrumentation/01-appinsights-bicep/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
