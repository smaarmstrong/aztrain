# Manage line endings and large binaries with `.gitattributes`

Windows and macOS developers keep fighting over CRLF churn, and someone
committed a 400 MB `.psd` straight into history and bloated every clone. Fix
both at the repository layer with a **`.gitattributes`** so the rules travel
with the repo instead of living in each person's local config.

Write **`.gitattributes`** in your workspace. The grader parses each line as
`<pattern> <attr...>` (Git's own format) and asserts the policy — any
attribute ordering is fine.

Requirements:

1. **Normalize text line endings.** A default rule `* text=auto` so Git
   normalizes text files to LF in the repository.
2. **Force LF on shell scripts.** `*.sh` must be `text eol=lf` (they break if
   checked out with CRLF).
3. **Mark a binary type as binary.** `*.png` (or another true binary) marked
   `binary` so Git never tries to diff or line-ending-munge it.
4. **Route large assets to Git LFS.** `*.psd` tracked through LFS —
   `filter=lfs diff=lfs merge=lfs -text` (this is exactly what
   `git lfs track "*.psd"` writes).

Rules:

- Comments (`#`) and blank lines are ignored.
- Each rule needs a pattern **and** at least one attribute.

> `.gitattributes` is configuration, not credentials — it holds no secrets.
