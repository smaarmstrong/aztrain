# Author a multi-stage Azure Pipeline (Build then Deploy)

Your team is moving a classic build-then-release pipeline to a single
YAML-based Azure Pipeline. CI should run automatically on the `main` branch,
build on a Microsoft-hosted Linux agent, and only start deploying once the
build stage has succeeded.

Edit `azure-pipelines.yml` in your workspace so it is a valid Azure Pipelines
definition that:

1. **Triggers** on the `main` branch (a `trigger:` that includes `main` —
   either the shorthand list form or `trigger.branches.include`).
2. Sets a **pool** using a Microsoft-hosted image, i.e. `pool.vmImage`
   (e.g. `ubuntu-latest`).
3. Has a top-level **`stages:`** list with at least two stages:
   - a stage named `Build` whose job(s) have `steps:` that build the app,
   - a stage named `Deploy` that **depends on** `Build`
     (`dependsOn: Build`) so it only runs after a green build.
4. Each stage contains at least one **job** with a `steps:` list (the
   classic `stages -> jobs -> steps` hierarchy).

Graded on **structure**, so any build/deploy commands that fit the shape
above pass. The YAML is parsed with `tools/yamlmini.py` — stick to plain
block YAML (no anchors, tags, or tabs).

Check your file parses as you go:

```sh
python3 tools/yamlmini.py azure-pipelines.yml --get stages.0.stage
```
