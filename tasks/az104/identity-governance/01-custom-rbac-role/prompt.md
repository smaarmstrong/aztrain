# Author a least-privilege custom RBAC role: VM Operator

None of the built-in roles fit: your on-call team must be able to **start,
restart, stop and monitor** virtual machines, but must **never** be able to
**delete** a VM or **create/modify role assignments** (no privilege
escalation). You've been asked to define a custom role for exactly this.

Write the role definition as JSON to `role.json` in your workspace, in the
shape `az role definition create` accepts.

Requirements — graded by parsing the JSON, so any equivalent JSON passes:

1. A human-readable `Name` (a non-empty string) and a non-empty `Description`.
2. `IsCustom` set to `true`.
3. An `Actions` array that **grants** the ability to:
   - read VMs — include `Microsoft.Compute/virtualMachines/read`
   - start a VM — include `Microsoft.Compute/virtualMachines/start/action`
   - restart a VM — include `Microsoft.Compute/virtualMachines/restart/action`
   - power off a VM — include `Microsoft.Compute/virtualMachines/powerOff/action`
   - read monitoring/metrics — include `Microsoft.Insights/metrics/read`
4. The role must **NOT** grant any of these dangerous operations (they must
   be absent from `Actions`, or a broad grant like `Microsoft.Compute/*` must
   be walked back with a matching `NotActions` entry so the effective
   permission is removed):
   - deleting VMs — `Microsoft.Compute/virtualMachines/delete`
   - writing role assignments — `Microsoft.Authorization/roleAssignments/write`
   - deleting role assignments — `Microsoft.Authorization/roleAssignments/delete`
5. An `AssignableScopes` array with at least one entry (a subscription- or
   resource-group-shaped scope string, e.g. `/subscriptions/<subId>`).

Tip: model it on the output of
`az role definition list --name "Virtual Machine Contributor"` — but tighter.

(No subscription is touched — this task grades the JSON document itself.)
