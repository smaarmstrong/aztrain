# Keep secrets and build junk out of the repo with `.gitignore`

A developer committed a `.env` full of connection strings and a signing
`.pfx` last sprint, and every checkout is polluted with `node_modules/` and
`bin/`. Stop it at the source: write a **`.gitignore`** that never lets those
land again.

Write **`.gitignore`** in your workspace. The grader reads the patterns
directly and checks that the required ones are present — and that you did
**not** over-ignore (a bare `*` or `**` that hides the whole tree fails).

Your `.gitignore` must exclude, at minimum:

1. Environment/secret files — `*.env` (dotenv files).
2. Certificate / signing material — `*.pfx`.
3. The Node dependency tree — `node_modules/`.
4. Build output — `bin/`.

Rules:

- Comments (`#`) and blank lines are fine.
- Do **not** add a catch-all that ignores everything (e.g. a line that is
  just `*`, `**`, `/`, or `*.*`) — that would hide your source too. The
  grader rejects it.

> `.gitignore` prevents secrets from being committed; it does not scrub ones
> already in history. Real secrets belong in a vault / your password manager,
> never in the tree.
