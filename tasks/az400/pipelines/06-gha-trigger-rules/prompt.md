# Control when a GitHub Actions workflow runs with trigger rules

A release workflow should only run when it matters — not on every push. Edit
`release.yml` in your workspace so its `on:` triggers are:

1. **Version tags**: on pushes of tags matching `v*` (use `push` → `tags`).
2. **A nightly schedule**: a `schedule` entry with a `cron` expression.
3. **Path-filtered pushes to main**: on `push` to the `main` branch, but only
   when files under `src/**` change (use `push` → `branches` **and** `paths`).
4. **Manual runs**: allow `workflow_dispatch`.

Keep a single job (any steps) so the file is a valid workflow.

Graded on **structure** — any cron value and any job body pass, as long as the
four trigger rules are present with the right shape. The YAML is parsed with
`tools/yamlmini.py`, so use plain block YAML (no anchors, tags, or tabs).

```sh
python3 tools/yamlmini.py release.yml --get on.schedule
```
