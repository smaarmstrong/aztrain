# KQL: top 3 computers by average CPU in the last hour

An on-call engineer asks: *"which three machines are hottest right now?"*
You have a Log Analytics `Perf` table (a canned snapshot of one is in this
task's `fixture.json` — same shape as the real thing).

Write your query in **`query.kql`** in your workspace. It must return the
**top 3 computers by average CPU** over the **last hour**, hottest first:

- Only `% Processor Time` samples count as CPU (`Perf` also carries memory
  counters — don't let them poison the average).
- "Last hour" means `TimeGenerated > ago(1h)`. The fixture freezes *now* (the
  engine reads it from the fixture's `@now` key), so results are
  deterministic — write the query exactly as you would against live data.
- Output columns: `Computer` and `AvgCpu` (the average `CounterValue`),
  exactly those names, 3 rows, descending.

Iterate as you go:

```sh
python3 tools/kqlmini.py tasks/az104/monitoring/01-kql-top-cpu/fixture.json \
    workspace/az104/monitoring/01-kql-top-cpu/query.kql --table
```

The grader compares your result rows (order matters) — any query that
produces them passes.
