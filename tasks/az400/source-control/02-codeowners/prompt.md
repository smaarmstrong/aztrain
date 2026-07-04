# Write a CODEOWNERS file for review routing

Reviews on your monorepo land on whoever is free, so the infra team keeps
missing changes to their Terraform. Add a **`CODEOWNERS`** file so the right
team is auto-requested on every pull request that touches their area.

Write **`CODEOWNERS`** in your workspace. It is graded by parsing the file the
way GitHub / Azure Repos does: each non-comment line is a **path pattern**
followed by one or more **owners** (an `@user`, `@org/team`, or an email).
Any reasonable owners are accepted — the grader checks that the required
paths are mapped and that the syntax is valid.

Required mappings:

1. A **catch-all** rule `*` with at least one default owner (the fallback
   reviewers for anything not matched by a more specific rule).
2. Everything under **`/infra/`** owned by an infrastructure team
   (e.g. `@acme/platform`).
3. All **`*.tf`** files owned by that same or another infra owner
   (Terraform belongs to platform wherever it lives).
4. Everything under **`/docs/`** owned by a docs/writer owner.

Rules:

- Comments start with `#`; blank lines are ignored.
- Every rule line must have a pattern **and** at least one owner; a pattern
  with no owner is a syntax error (it would silently un-own that path).
- Owners must look like owners: `@name`, `@org/team`, or `an@email.address`.

> CODEOWNERS carries team handles, never tokens. Keep any real credentials in
> your password manager.
