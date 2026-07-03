# KQL: find a caller's failed Compute operations

Security is investigating the account **`priya@contoso.com`**: *"in the last
hour, which Compute control-plane operations did she attempt that FAILED?"*
You have a canned Log Analytics `AzureActivity` snapshot in this task's
`fixture.json` (same shape as the real table). Note the columns
`Caller`, `OperationNameValue`, `ActivityStatusValue`, and `ResourceGroup`.

Write your query in **`query.kql`** in your workspace. It must return only
`priya@contoso.com`'s **failed** operations against **Compute** resources:

- Keep only the **last hour** (`TimeGenerated > ago(1h)`). The fixture freezes
  *now* via its `@now` key, so results are deterministic.
- Match the caller with a **case-sensitive** equality (`==`). The log also
  contains a differently-cased `PRIYA@contoso.com` entry — that is a different
  principal and must **not** match.
- Keep only rows whose `ActivityStatusValue` is exactly `Failed`.
- Keep only Compute operations. Use `has` for a whole-token match
  (`OperationNameValue has "compute"`) — this matches the `Compute` token in
  `Microsoft.Compute/...` without also matching an operation that merely
  contains those letters elsewhere.
- Output exactly two columns, in this order: `OperationNameValue` and
  `ResourceGroup`, sorted by `OperationNameValue` **ascending**.

Iterate as you go:

```sh
python3 tools/kqlmini.py tasks/az104/monitoring/03-kql-activity-failures/fixture.json \
    workspace/az104/monitoring/03-kql-activity-failures/query.kql --table
```

The grader compares your result rows in order — any query that produces them
passes.
