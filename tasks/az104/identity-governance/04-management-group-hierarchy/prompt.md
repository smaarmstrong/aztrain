# Declare a management group hierarchy with Bicep

Your org is standing up a governance hierarchy: a top-level **Platform**
management group, with a **Landing Zones** management group nested under it.
Management groups are tenant-level objects, so this deployment targets the
tenant, not a resource group.

Write `main.bicep` (in your workspace).

Requirements — graded on the **compiled ARM template**:

1. `targetScope` is **`tenant`** (management groups can only be created at
   tenant scope).
2. A parameter `platformMgName` (string) and a parameter `landingZonesMgName`
   (string), so the group names aren't hard-coded.
3. A parent `Microsoft.Management/managementGroups` resource named from
   `platformMgName`, with a non-empty `displayName`.
4. A child `Microsoft.Management/managementGroups` resource named from
   `landingZonesMgName` whose `details.parent.id` points at the Platform
   management group (use the resource-id form
   `tenant/providers/Microsoft.Management/managementGroups/<name>` — the
   `managementGroupResourceId(...)` helper or an `mg.id` reference both work).

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
