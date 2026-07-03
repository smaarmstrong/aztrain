# Assign the built-in "Allowed locations" policy with Bicep

Authoring a policy is only half the job — governance happens when it's
**assigned** at a scope with the right **parameters**. Write `main.bicep`
(in your workspace) that assigns Azure's built-in *"Allowed locations"* policy
so that resources may only be deployed to a chosen set of regions.

The built-in definition id is fixed:
`/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c`

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A parameter `allowedLocations` of type `array` **defaulting to
   `['uksouth', 'ukwest']`** — the caller can override the regions.
2. Exactly one `Microsoft.Authorization/policyAssignments` resource.
3. Its `policyDefinitionId` is the built-in "Allowed locations" id above.
4. It passes the definition's `listOfAllowedLocations` parameter, wired to the
   `allowedLocations` parameter (i.e. `parameters.listOfAllowedLocations.value`
   comes from `allowedLocations`).
5. Give the assignment a non-empty `displayName`.

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself. A resource
group is the default deployment scope, which is fine here.)
