# Author Bicep for a Log Analytics workspace + email action group

You're standing up the monitoring foundation for a new subscription: a Log
Analytics workspace to collect logs, and an action group so alerts can reach
the on-call inbox. Write `main.bicep` (in your workspace) that a pipeline could
deploy into any resource group.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `location` **defaulting to the resource group's
   location**, used as the workspace's location.
2. A string parameter `workspaceName` (no default), and a string parameter
   `opsEmail` (no default) for the notification address.
3. Exactly one `Microsoft.OperationalInsights/workspaces` resource:
   - name comes from the `workspaceName` parameter
   - SKU name `PerGB2018`
   - `retentionInDays` set to **90**
4. Exactly one `Microsoft.Insights/actionGroups` resource:
   - `groupShortName` no longer than 12 characters (the Azure limit)
   - `enabled` **true**
   - exactly one entry under `emailReceivers` whose `emailAddress` comes from
     the `opsEmail` parameter
5. Two outputs: `workspaceId` (the workspace resource id) and `actionGroupId`
   (the action group resource id).

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/monitoring/06-bicep-action-group-loganalytics/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
