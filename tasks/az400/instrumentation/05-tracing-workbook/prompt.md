# Build an Azure Monitor workbook for distributed tracing

When a request is slow, the cause is often a downstream call — a database, an
HTTP dependency, a queue. Application Insights captures each of those as
**dependency telemetry** in the `AppDependencies` table, correlated to the parent
request by `OperationId`. You'll build an Azure Monitor **workbook** that an SRE
opens to inspect these end-to-end traces.

Edit **`workbook.json`** in your workspace (a starter stub is provided) so it is a
valid workbook template with the tiles the team needs.

Requirements — graded by parsing the JSON, so any structurally-correct workbook
passes:

1. The workbook has a `version` and an `items` array.
2. At least one **text/markdown tile** (`type` 1) giving the workbook context.
3. At least one **query tile** (`type` 3) whose `content.query` holds a KQL
   query. Across your query tiles:
   - one query inspects **dependency telemetry** (the `AppDependencies` table);
   - one query **correlates traces** — either projecting/grouping by
     `OperationId`, or `join`-ing requests to dependencies on it;
   - queries are **time-scoped** (use `ago(...)` / filter `TimeGenerated`), as
     real Application Insights queries are.

The query text, tile titles, and visualizations are yours to design. Nothing is
deployed — this task grades the workbook definition itself.
