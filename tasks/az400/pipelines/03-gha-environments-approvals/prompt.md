# Gate a deploy job behind a GitHub environment and a build dependency

Production deploys must only happen after the build succeeds, and only through
a protected **environment** (so the required-reviewers / approval check on that
environment can hold the deploy for sign-off).

Edit `release.yml` in your workspace so it has two jobs:

1. A `build` job on `ubuntu-latest` that builds and uploads/produces the
   artifact (a couple of `run:` steps are fine).
2. A `deploy` job that:
   - declares `needs: build` so it cannot start until `build` succeeds, and
   - targets a named `environment:` called **`production`** (this is the
     GitHub environment whose protection rules enforce approvals).

Graded on **structure** — the ordering (`needs`) and the environment binding
are what matter, not the deploy commands themselves. Parsed by
`tools/yamlmini.py`; keep to plain block YAML (no anchors, tags, or tabs).

Check the wiring:

```sh
python3 tools/yamlmini.py release.yml --get jobs.deploy.needs
python3 tools/yamlmini.py release.yml --get jobs.deploy.environment
```
