# Deploy to Azure from GitHub Actions with OIDC (no stored secret)

Security has banned long-lived cloud credentials in CI. Convert the deploy
workflow to **passwordless** authentication using **workload identity
federation / OpenID Connect**: GitHub mints a short-lived OIDC token that
`azure/login` exchanges for an Azure access token — nothing is stored.

Edit `deploy.yml` in your workspace so that:

1. The workflow (or the `deploy` job) grants the OIDC permission the token
   request needs:
   ```yaml
   permissions:
     id-token: write
     contents: read
   ```
2. A step uses **`azure/login`** and authenticates by **federation**, passing
   `client-id`, `tenant-id`, and `subscription-id` (these come from
   `${{ secrets.* }}` or `${{ vars.* }}` — they are identifiers, not
   passwords).
3. There is **NO** stored credential: the `azure/login` step must not use a
   `creds:` JSON blob and must not pass a client secret / password of any kind.

Graded **by inspection** — the OIDC permission must be present, the federated
`azure/login` shape must be there, and there must be no `creds:` or secret
password anywhere. Parsed by `tools/yamlmini.py`; keep to plain block YAML
(no anchors, tags, or tabs).

Check the permission parses:

```sh
python3 tools/yamlmini.py deploy.yml --get permissions.id-token
```
