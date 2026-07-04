# Roll out a deployment with a canary strategy

To reduce blast radius, production rollouts should go out **progressively**:
ship to a small slice of infrastructure first, watch it, then widen. Azure
Pipelines deployment jobs support this directly with the **`canary`**
strategy and its `increments:`.

Your workspace has a deployment job using a plain `runOnce` strategy (all at
once). Change it to a progressive rollout so that:

1. The deployment job's **`strategy:`** is a **`canary`** strategy.
2. The canary strategy declares **`increments:`** — a list of percentages
   (e.g. `[10, 20]`) controlling how the rollout widens.
3. The `canary.deploy.steps:` contains the deployment steps.

(If you prefer, a `rolling` strategy with `maxParallel` is an acceptable
progressive alternative — but the grader below expects the canary shape, so
implement canary.)

Graded on **structure**: a deployment job whose strategy is `canary`, with an
`increments:` list and `deploy.steps`. The YAML is parsed with
`tools/yamlmini.py` — plain block YAML only (no anchors, tags, or tabs).

Check your file parses as you go:

```sh
python3 tools/yamlmini.py azure-pipelines.yml --get stages.0.jobs.0.strategy.canary.increments.0
```
