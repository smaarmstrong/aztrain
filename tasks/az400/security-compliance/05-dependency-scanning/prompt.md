# Enable Dependabot dependency scanning

Your repo has no automated watch on its open-source dependencies, so a
vulnerable package could sit unnoticed. Turn on Dependabot version updates so
it opens PRs when a dependency has a newer (or patched) release.

Edit `dependabot.yml` in your workspace (this is `.github/dependabot.yml`) so
that:

1. It is a version-2 Dependabot config — top-level `version: 2`.
2. It has an `updates:` list with **at least one** entry that specifies:
   - a `package-ecosystem` (e.g. `npm`, `pip`, `nuget`, `github-actions`,
     `docker`, `maven`, `gomod`…),
   - a `directory` (e.g. `/`), and
   - a `schedule` with an `interval` (`daily`, `weekly`, or `monthly`).

Test your file parses:

```sh
python3 tools/yamlmini.py dependabot.yml --get updates.0.package-ecosystem
```

Grading parses the YAML and asserts the config (structure, not wording), so any
valid Dependabot config passes. Keep it in the simple block style shown (no
anchors, tags, or tabs).
