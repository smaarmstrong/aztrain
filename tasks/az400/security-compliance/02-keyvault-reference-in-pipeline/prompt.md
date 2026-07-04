# Fetch a deploy secret from Key Vault at pipeline time

A teammate's deploy workflow hardcoded a database connection string as a plain
environment value. Rewrite it so the secret is **never stored in the repo**:
the workflow logs in to Azure with **OpenID Connect (no client secret)** and
pulls the connection string out of Key Vault at run time.

Edit `deploy.yml` in your workspace so that:

1. The workflow grants the job the permissions OIDC needs — top-level or
   job-level `permissions:` with `id-token: write` (and `contents: read`).
2. The `deploy` job runs on an Ubuntu runner and has a `steps:` list.
3. One step uses **`azure/login@v2`** and authenticates **without a client
   secret** — it must supply `client-id`, `tenant-id` and `subscription-id`
   (via `${{ secrets.* }}` references) and must NOT pass a `creds:` /
   `client-secret:` input.
4. One step fetches the secret from Key Vault — use the
   **`azure/get-keyvault-secrets@v1`** action (with a `keyvault:` input naming
   the vault and a `secrets:` input naming the secret), OR run `az keyvault
   secret show` in a script step.
5. There is **no plaintext connection string** anywhere in the file — the value
   only ever comes from Key Vault.

The workflow is graded by parsing the YAML (structure, not wording), so any
correct shape passes. Keep the YAML in the simple block style shown in the
starter (no anchors, tags, or tabs).
