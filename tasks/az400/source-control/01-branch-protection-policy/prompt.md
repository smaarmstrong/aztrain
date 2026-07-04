# Author a branch protection ruleset for `main`

Your team keeps merging half-reviewed code straight to `main` and someone
force-pushed over a release last week. You will codify the guard rails as a
**GitHub repository ruleset** (the JSON you would POST to
`/repos/{owner}/{repo}/rulesets`, or import in the UI) so the policy lives in
source control instead of a screenshot.

Write **`ruleset.json`** in your workspace. It is graded on structure with the
stdlib JSON parser, so any well-formed ruleset that expresses the policy
passes — key order and extra metadata do not matter.

Requirements:

1. Top-level `name` (any string) and `enforcement` set to `"active"`.
2. `target` is `"branch"`, and `conditions.ref_name.include` targets the
   default branch (`"~DEFAULT_BRANCH"` or an explicit `refs/heads/main`).
3. A `rules` array (GitHub ruleset shape: each rule is an object with a
   `type`, some carry a `parameters` object) that enforces **all** of:
   - **Pull requests required** — a rule of type `pull_request` whose
     `parameters.required_approving_review_count` is **at least 1**.
   - **Status checks must pass** — a rule of type `required_status_checks`
     whose `parameters.required_status_checks` lists at least one check
     (each entry has a `context`). Include a check named `build`.
   - **No force pushes** — a rule of type `non_fast_forward` (this is how a
     ruleset blocks force-pushes / history rewrites on the branch).

You are describing policy, not touching a live repo — nothing is deployed.

> Reference the schema, never your credentials. A ruleset carries no secrets;
> if you ever need a token, keep it in your password manager.
