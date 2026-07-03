# Interpret role assignments: find the over-privileged users

An access review landed on your desk. You've been handed the output of
`az role assignment list --all` (flattened into a table called
**`RoleAssignments`**) and asked to find the assignments that break
least-privilege: **individual users** (not groups or service principals) who
hold the **`Owner`** role directly at **subscription** scope.

Those are the assignments a reviewer would challenge first — an Owner grant
should go to a group, and rarely at the whole subscription.

Each row in `RoleAssignments` has these columns:

| column | meaning |
|---|---|
| `principalName` | display name of the user / group / SP |
| `principalType` | `User`, `Group`, or `ServicePrincipal` |
| `roleDefinitionName` | e.g. `Owner`, `Contributor`, `Reader` |
| `scopeLevel` | `Subscription`, `ResourceGroup`, or `Resource` |
| `scope` | the full scope path |

Write a query to `query.kql` in your workspace that returns **exactly** the
offending assignments, with these two columns and **only** these:

- `principalName`
- `roleDefinitionName`

Keep the rows **sorted by `principalName` ascending**. (The grader checks
order.)

Test your query against the fixture:

```sh
python3 tools/kqlmini.py tasks/az104/identity-governance/06-interpret-role-assignments/fixture.json query.kql
```

(No subscription is touched — the query runs against the checked-in fixture.)
