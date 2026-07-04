# Author a metric alert rule for a spike in failed requests

Your release pipeline needs a safety net: after each deployment, if the service
starts throwing errors, on-call must be paged automatically. You'll express this
as an Azure Monitor **metric alert** over your Application Insights component's
built-in `requests/failed` metric.

Edit **`alert.json`** in your workspace (a starter stub is provided) so it
describes a `Microsoft.Insights/metricAlerts` resource that fires when the
service returns **too many failed requests over a 5-minute window**.

Requirements — graded by parsing the JSON, so any structurally-correct rule
passes:

1. `type` is `Microsoft.Insights/metricAlerts` and the rule is `enabled`.
2. `properties.severity` is a high severity (Sev0, Sev1, or Sev2).
3. Evaluation window: `properties.windowSize` is `PT5M` (5 minutes) and
   `properties.evaluationFrequency` is set to an ISO-8601 duration (e.g. `PT1M`).
4. `properties.scopes` targets an **Application Insights component**
   (`Microsoft.Insights/components`).
5. Under `properties.criteria.allOf`, one condition watches the
   **failed-requests** metric (`metricName` containing `failed`):
   - `operator` of `GreaterThan`
   - a positive numeric `threshold`
   - `timeAggregation` of `Total` (count the failures across the window)
6. `properties.actions` references an action group via `actionGroupId`, so the
   alert actually notifies someone.

The values (exact threshold, action group name, component name) are yours —
wire the resource IDs however you like. Nothing is deployed; this task grades the
alert definition itself.
