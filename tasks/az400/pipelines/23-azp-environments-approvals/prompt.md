# Deploy via a deployment job targeting a YAML environment

Production deploys must run through an Azure DevOps **environment** so that
the approvals and checks configured on that environment (manual approval,
branch control, business hours) gate the release. In YAML you get this by
using a **deployment job** that targets an `environment:`, rather than a
plain `job:`.

Your workspace has a Deploy stage that uses an ordinary `job:` with steps.
Convert it into a deployment job so that:

1. Inside the Deploy stage's `jobs:`, the entry is a **`deployment:`** job
   (a `deployment:` key naming the job) instead of a `job:`.
2. The deployment job targets an **`environment:`** named `production`
   (this is what carries the approvals/checks).
3. The deployment job uses a **`strategy:`** — a `runOnce` strategy whose
   `deploy.steps:` contains the deployment steps.

Graded on **structure**: a deployment job targeting the `production`
environment with a `runOnce` strategy that has deploy steps. The YAML is
parsed with `tools/yamlmini.py` — plain block YAML only (no anchors, tags,
or tabs).

Check your file parses as you go:

```sh
python3 tools/yamlmini.py azure-pipelines.yml --get stages.0.jobs.0.environment
```
