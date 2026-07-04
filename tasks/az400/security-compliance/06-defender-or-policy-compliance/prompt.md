# Author an Azure Policy that denies unencrypted storage

Your Defender for Cloud security baseline requires that data at rest and in
transit is always encrypted. To enforce it, author a custom **Azure Policy
definition** that **blocks** any storage account that does not enforce HTTPS
(secure transfer) — a non-compliant deployment should be refused, not merely
flagged.

Edit `policy.json` in your workspace so it is a valid Azure Policy definition
whose `properties` contain:

1. A `policyRule` with an `if` condition that **targets storage accounts** —
   it tests `type` equals `Microsoft.Storage/storageAccounts`.
2. The rule also inspects the secure-transfer setting — a condition on
   `Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly` (checking it is
   not `true`, e.g. `notEquals: true` or `equals: false`).
3. A `then` block whose **`effect` is `Deny`** (or a `[parameters('effect')]`
   reference whose parameter **defaults to `Deny`**).
4. `mode` set to `Indexed` and a `displayName`.

Grading parses the JSON and asserts the target + effect (structure, not exact
wording), so any equivalent policy passes.
