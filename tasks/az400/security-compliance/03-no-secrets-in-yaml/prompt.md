# Purge hardcoded secrets from a pipeline

A secret scanner flagged `release.yml`: it commits a storage account key, a
registry password and a personal access token straight into the workflow file.
Anyone with read access to the repo now has production credentials.

Fix `release.yml` in your workspace so that:

1. **No secret literal remains in the file.** Remove every hardcoded value —
   there must be no `AccountKey=...`, no `password:` with an inline value, and
   no pasted token / long base64 blob.
2. **Every secret is referenced indirectly** instead. Pull each value from a
   secret store using GitHub encrypted secrets (`${{ secrets.NAME }}`), an
   Azure Pipelines variable (`$(NAME)`), or a Key Vault lookup — the workflow
   must still have the values available at run time, just not in the text.
3. Keep the workflow otherwise intact: it still has its `jobs:` with a
   `runs-on` and a `steps:` list.

Grading is **by inspection**: the grader reads the file and fails if it finds
any hardcoded secret literal, and it requires that secrets are wired in through
an indirect reference. Keep the YAML in the simple block style shown (no
anchors, tags, or tabs).
