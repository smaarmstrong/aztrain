# Grant a group the Reader role at resource-group scope (Bicep)

The audit team needs **read-only** visibility into one resource group — nothing
more, nowhere else. Best practice is to assign a role to a **group** (not
individuals) at the **narrowest scope** that does the job. You'll express that
grant as IaC.

Write `main.bicep` (in your workspace) that creates a role assignment giving an
Entra group the built-in **Reader** role at the deployment's resource-group
scope.

Two facts you'll need:

- The **Reader** built-in role definition id (GUID):
  `acdd72a7-3385-48ef-bd42-f606fba81ae7`
- A role assignment's own resource name must be a GUID; the idiomatic way is
  `guid(...)` over the scope + principal + role so it's stable and unique.

Requirements — graded on the **compiled ARM template**:

1. A parameter `principalId` (string) — the object id of the group to grant.
2. Exactly one `Microsoft.Authorization/roleAssignments` resource.
3. Its `properties.roleDefinitionId` resolves to the built-in **Reader** role
   (its value must contain the Reader GUID above — using
   `subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ...)`
   is the clean way).
4. Its `properties.principalId` comes from the `principalId` parameter.
5. Set `properties.principalType` to **`Group`** (best practice; lets Azure
   skip the just-created-principal check).
6. The assignment's `name` is produced by the `guid(...)` function (a stable,
   deterministic name).

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself. The default
resource-group deployment scope is exactly the scope we want here.)
