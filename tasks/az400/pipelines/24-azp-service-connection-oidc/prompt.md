# Deploy to Azure via a workload-identity service connection (no inline secrets)

A security review flagged your deployment pipeline: it authenticates to Azure
by pasting a service-principal client secret straight into the YAML. You must
switch to a **workload-identity-federation (OIDC) service connection** so no
credential ever lives in the file — the `AzureCLI@2` task authenticates
through the service connection, and the platform mints a short-lived token.

Your workspace has `azure-pipelines.yml` with an `AzureCLI@2` step that logs
in with a hardcoded client id / secret / tenant. Fix it so that:

1. The `AzureCLI@2` task authenticates via a service connection: its
   `inputs` set **`azureSubscription:`** to the name of the service
   connection (e.g. `azure-prod-oidc`). It must NOT run any `az login`
   itself — the task handles auth.
2. There is **no inline credential anywhere** in the file: no `--password`,
   no `clientSecret`/`client-secret`, no `AccountKey=`, no `az login ... -p`,
   and no literal secret value. If you must reference a secret, it comes from
   a variable group / Key Vault via `$(...)`, never as a literal.

Graded on **structure + inspection**: the `AzureCLI@2` step references a
service connection through `azureSubscription`, and the file contains zero
inline secret literals or `az login` credential flags. The YAML is parsed
with `tools/yamlmini.py` — plain block YAML only (no anchors, tags, or tabs).

Check your file parses as you go:

```sh
python3 tools/yamlmini.py azure-pipelines.yml --get steps.0.inputs.azureSubscription
```
