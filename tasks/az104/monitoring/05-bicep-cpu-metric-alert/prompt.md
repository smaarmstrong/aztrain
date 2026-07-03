# Author Bicep for a VM CPU > 80% metric alert

On-call keeps missing hot VMs. Write `main.bicep` (in your workspace) that a
pipeline could deploy to create a **static-threshold metric alert** that fires
when a virtual machine's CPU is sustained above 80%.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. String parameters `vmResourceId` (the VM to watch) and `actionGroupId` (the
   action group to notify). No defaults needed.
2. Exactly one `Microsoft.Insights/metricAlerts` resource.
3. Its `scopes` array contains the `vmResourceId` parameter (the alert targets
   that VM).
4. `severity` **2**, `enabled` **true**.
5. A single static-threshold criterion under `criteria.allOf`:
   - `metricName` `Percentage CPU`
   - `operator` `GreaterThan`
   - `threshold` **80**
   - `timeAggregation` `Average`
6. An `actions` entry whose `actionGroupId` is the `actionGroupId` parameter,
   so the alert notifies that action group.
7. An output named `alertId` carrying the alert's resource id.

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/monitoring/05-bicep-cpu-metric-alert/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
