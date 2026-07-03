# KQL: count heartbeats per hour with bin()

A capacity review needs a time-series of agent liveness: *"how many
`Heartbeat` records did we get in each of the last four hours?"* You have a
canned Log Analytics `Heartbeat` snapshot in this task's `fixture.json` (same
shape as the real table).

Write your query in **`query.kql`** in your workspace. It must bucket the
heartbeats into **1-hour bins** and count them per bin:

- Keep only records from the **last 4 hours** (`TimeGenerated > ago(4h)`). The
  fixture freezes *now* via its `@now` key, so results are deterministic —
  write the query exactly as you would against live data.
- Bucket on `TimeGenerated` using `bin(TimeGenerated, 1h)` and `count()` the
  rows in each bucket.
- Output exactly two columns, in this order: `Hour` (the bin start rendered as
  text with `tostring(...)`) and `Beats` (the count). One row per hour,
  **oldest hour first**.

Iterate as you go:

```sh
python3 tools/kqlmini.py tasks/az104/monitoring/02-kql-heartbeat-bins/fixture.json \
    workspace/az104/monitoring/02-kql-heartbeat-bins/query.kql --table
```

The grader compares your result rows in order — any query that produces them
passes.
