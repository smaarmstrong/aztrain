# Gate `main` behind review + a security status check

Code has been landing on `main` with no review and with the CodeQL scan still
red. Lock the branch down with a GitHub branch-protection rule so nothing
merges until a human has reviewed it AND the security scan is green.

This is the body you would `PUT` to
`/repos/{owner}/{repo}/branches/main/protection`. Edit `protection.json` in
your workspace so that it is valid JSON expressing this policy:

1. **Pull requests are required before merging** — a
   `required_pull_request_reviews` object exists with
   `required_approving_review_count` **>= 1**, and `dismiss_stale_reviews` set
   to `true`.
2. **A status check must pass** — `required_status_checks` exists with
   `strict: true` and a `contexts` (or `checks`) list that includes the code
   scanning check (a context containing `codeql`, `code-scanning`, or a
   `CodeQL` name).
3. **The rule applies to admins too** — `enforce_admins` is `true`.
4. **Force-pushes and deletions are blocked** — `allow_force_pushes` is `false`
   and `allow_deletions` is `false`.

Grading parses the JSON and asserts the gate (structure, not key ordering), so
any equivalent JSON passes.
