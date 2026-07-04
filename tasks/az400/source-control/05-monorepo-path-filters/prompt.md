# Path-filter a monorepo CI trigger

Your team moved to a **trunk-based** monorepo: everyone integrates to `main`
behind short-lived PRs. But the CI now runs the whole world on every commit,
even a README typo, so the `services/api` build queue is always jammed.

Scope the workflow so the API build fires **only** when the API's code
changes — and only on the trunk integration path (pushes to `main` and PRs
targeting `main`).

Write **`ci.yml`** in your workspace (GitHub Actions style). It is graded by
parsing structure with the repo's `yamlmini` loader, so wording is free but
the shape must hold. Keep to plain block YAML — no anchors, tags, or tabs.

Requirements:

1. A top-level `on:` trigger with **both** `push` and `pull_request`.
2. Both triggers are limited to the **`main`** branch (`branches: [main]`).
3. Both triggers carry a **`paths:`** filter scoping them to the API service
   (e.g. `services/api/**`) so unrelated changes do not trigger the build.
4. A `jobs:` map with **one** job that has a `runs-on` and a non-empty
   `steps:` list (each step is a mapping, e.g. with `run:` or `uses:`).

No secrets belong in a trigger definition; keep credentials in a secret store.
