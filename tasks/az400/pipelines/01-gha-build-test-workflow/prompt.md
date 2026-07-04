# Author a GitHub Actions CI workflow triggered on push and PR

Your team wants continuous integration on the `main` branch: every push to
`main` and every pull request that targets `main` must build the app and run
its tests on a hosted Linux runner.

Edit `ci.yml` in your workspace so it is a valid GitHub Actions workflow that:

1. **Triggers** on both `push` **and** `pull_request`, each scoped to the
   `main` branch (use the `on:` / `branches:` shape).
2. Defines a job named `build` that runs on an Ubuntu hosted runner
   (`runs-on: ubuntu-latest`).
3. The `build` job has a `steps:` list that, in order:
   - checks the code out (an `actions/checkout` step),
   - sets up a language runtime (a `*/setup-*` action — e.g.
     `actions/setup-node`, `actions/setup-python`, `actions/setup-dotnet`),
   - runs a build command (a `run:` step),
   - runs the tests (a `run:` step).

Graded on **structure**, so any runtime and any build/test commands that fit
the shape above pass. The YAML is parsed with `tools/yamlmini.py` — stick to
plain block YAML (no anchors, tags, or tabs).

Check your file parses as you go:

```sh
python3 tools/yamlmini.py ci.yml --get jobs.build.runs-on
```
