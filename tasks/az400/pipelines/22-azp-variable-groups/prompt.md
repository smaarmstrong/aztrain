# Wire a variable group and pipeline variables into a job

Your deployment credentials and shared settings live in an Azure DevOps
**variable group** called `prod-settings` (managed in the Library, often
Key Vault-backed). Your pipeline also needs a couple of plain pipeline
variables. You must consume both without hardcoding values in a step.

Edit `azure-pipelines.yml` so it uses the **list form** of `variables:`:

1. A **variable group reference** — an entry `- group: prod-settings`.
2. At least one **pipeline variable** in name/value form — an entry with
   `- name: buildConfiguration` and a `value:` (e.g. `Release`).
3. A `script`/step that **consumes a variable** through the macro syntax
   `$(...)` — e.g. `echo $(buildConfiguration)` or referencing a value that
   came from the group. (Do NOT paste any secret literal; reference it via
   `$(...)`.)

Graded on **structure**: the `variables:` list must contain both a `- group:`
reference and a named pipeline variable, and a step must reference a variable
with `$(...)`. The YAML is parsed with `tools/yamlmini.py` — plain block YAML
only (no anchors, tags, or tabs).

Check your file parses as you go:

```sh
python3 tools/yamlmini.py azure-pipelines.yml --get variables.0.group
```
