# Extract pipeline steps into a reusable YAML template

Three of your pipelines copy-paste the same build-and-test steps. You want to
DRY them up into a **reusable YAML template** that takes parameters, then have
the main pipeline reference it.

Your workspace has `azure-pipelines.yml` with the build steps inlined. Refactor
so that:

1. A template file **`templates/build-job.yml`** defines the reusable unit as a
   `steps:` template. It declares **`parameters:`** — at least a
   `buildConfiguration` parameter (with a default) — and its steps reference
   that parameter with the `${{ parameters.buildConfiguration }}` runtime
   syntax.
2. `azure-pipelines.yml` **references** the template with a
   `- template: templates/build-job.yml` entry (inside a job's `steps:`) and
   **passes** `parameters:` to it, setting `buildConfiguration`.
3. The main pipeline still keeps its `trigger` and `pool.vmImage`.

Graded on **structure**: the template must declare a `buildConfiguration`
parameter and use it, and the main file must reference the template and pass
that parameter. The YAML is parsed with `tools/yamlmini.py` — plain block YAML
only (no anchors, tags, or tabs).

Check both files parse as you go:

```sh
python3 tools/yamlmini.py azure-pipelines.yml --get steps
python3 tools/yamlmini.py templates/build-job.yml --get parameters.0.name
```
