# KQL: count failed requests by operation in the last hour

An SRE triaging an incident asks: *"which operations are failing right now, and
how badly?"* Application Insights writes every server request into the
`AppRequests` table (a canned snapshot with the real column shape is in this
task's `fixture.json`: `TimeGenerated`, `Name`, `OperationName`, `Success`,
`ResultCode`, `DurationMs`).

Write your query in **`query.kql`** in your workspace. It must return the
**count of FAILED requests grouped by operation**, over the **last hour**:

- A request failed when `Success == false` (don't rely on `ResultCode` string
  parsing — `Success` is the boolean Application Insights sets).
- "Last hour" means `TimeGenerated > ago(1h)`. The fixture freezes *now* (the
  engine reads it from the fixture's `@now` key), so results are deterministic —
  write the query exactly as you would against live data.
- Output columns: `OperationName` and `FailedCount` (the number of failed
  requests for that operation), exactly those names. Only operations that had at
  least one failure in the window should appear.

Iterate as you go:

```sh
python3 tools/kqlmini.py tasks/az400/instrumentation/02-kql-request-failures/fixture.json \
    workspace/az400/instrumentation/02-kql-request-failures/query.kql --table
```

The grader compares your result rows as a set — any query that produces them
passes, in any order.
