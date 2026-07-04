# KQL: find operations breaching the latency SLO in the last hour

Your service has a latency SLO: **a request is "slow" if it takes longer than
500 ms**. During a reliability review you need to know which operations are
breaching that budget so you can prioritise the fix.

Application Insights records every request in the `AppRequests` table (a canned
snapshot is in this task's `fixture.json`, with the real columns:
`TimeGenerated`, `Name`, `OperationName`, `Success`, `ResultCode`,
`DurationMs`).

Write your query in **`query.kql`** in your workspace. Over the **last hour**,
for each operation, report **how many requests breached the 500 ms SLO** and the
**slowest request seen**, keeping only operations that breached at least once:

- "Last hour" means `TimeGenerated > ago(1h)`. The fixture freezes *now* via its
  `@now` key, so results are deterministic.
- A request breaches the SLO when `DurationMs > 500`.
- Output columns, exactly these names:
  - `OperationName`
  - `SlowCount` — number of requests over 500 ms for that operation
  - `MaxDurationMs` — the maximum `DurationMs` for that operation
- Only rows with `SlowCount > 0` should appear.

> `percentile()` is not available in this offline engine — express the SLO as a
> threshold count (`countif`) plus `max()`, which is exactly how you'd cheaply
> alert on an SLO breach without a percentile aggregation.

Iterate as you go:

```sh
python3 tools/kqlmini.py tasks/az400/instrumentation/03-kql-p95-latency/fixture.json \
    workspace/az400/instrumentation/03-kql-p95-latency/query.kql --table
```

The grader compares your result rows as a set — any query that produces them
passes, in any order.
