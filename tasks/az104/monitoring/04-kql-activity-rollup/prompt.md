# KQL: per-resource-group activity rollup

Ops wants a one-glance health table from the control-plane log: *"for the last
hour, per resource group — how many operations ran, how many failed, and how
many distinct people/identities were involved?"* You have a canned Log
Analytics `AzureActivity` snapshot in this task's `fixture.json` with columns
`Caller`, `ResourceGroup`, and `ActivityStatusValue`.

Write your query in **`query.kql`** in your workspace. Produce one row per
resource group with three aggregates:

- Keep only the **last hour** (`TimeGenerated > ago(1h)`). The fixture freezes
  *now* via its `@now` key, so results are deterministic.
- `Total` — total operations in the group, via `count()`.
- `Failed` — how many had `ActivityStatusValue == "Failed"`, via
  `countif(...)`.
- `Callers` — how many **distinct** `Caller` values, via `dcount(Caller)`.
- Group `by ResourceGroup`. Sort by `Total` **descending**; break ties by
  `ResourceGroup` **ascending**.

Output columns: `ResourceGroup`, `Total`, `Failed`, `Callers`.

Iterate as you go:

```sh
python3 tools/kqlmini.py tasks/az104/monitoring/04-kql-activity-rollup/fixture.json \
    workspace/az104/monitoring/04-kql-activity-rollup/query.kql --table
```

The grader compares your result rows in order — any query that produces them
passes.
