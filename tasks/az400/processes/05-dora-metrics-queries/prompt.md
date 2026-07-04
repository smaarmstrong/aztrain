# Build a flow-of-work dashboard from the DORA metrics

Leadership wants one dashboard that shows how fast and how safely you ship.
Define it as data: the four DORA metrics — the industry standard for delivery
performance and recovery — each backed by a query the dashboard can run.

Complete `dora-dashboard.json` in your workspace. The `metrics` array must have
**one entry per DORA metric**, and each entry needs a `title`/`key` plus a
non-empty `query` (KQL over your telemetry tables is fine). Cover all four:

1. **Lead time for changes** (commit -> production, e.g. median hours).
2. **Deployment frequency** (successful prod deploys per day).
3. **Change failure rate** (share of deploys that cause an incident).
4. **Time to restore service** (a.k.a. time to recovery / MTTR).

Graded by parsing the JSON: at least four metrics, each with a real query, and
all four DORA metrics represented. Any correct set of queries passes.

Objective: *Design and implement a dashboard, including flow of work, such as
cycle times, time to recovery, and lead time.*
