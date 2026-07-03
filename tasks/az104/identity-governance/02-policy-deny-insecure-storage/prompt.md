# Author an Azure Policy that denies storage accounts without HTTPS-only

Compliance requires that **no storage account may accept plain-HTTP traffic**.
Rather than fixing accounts after the fact, you'll block non-compliant ones at
create/update time with a custom Azure Policy definition set to **deny**.

Write the policy definition to `policy.json` in your workspace, in the shape
`az policy definition create --rules` (plus `--params`/`--mode`) expects — i.e.
a document with a `properties` object containing `policyRule`, or the rule
object directly. Either top-level shape is accepted.

Requirements — graded by parsing the JSON:

1. `mode` is `Indexed` (the correct mode for resource-type policies that carry
   tags/locations). It may live at the top level or under `properties`.
2. A `policyRule` with an `if` condition and a `then` block.
3. The `then.effect` is **`deny`** (or a `[parameters('effect')]` reference
   whose parameter **defaults to `deny`**).
4. The `if` condition targets **storage accounts that are NOT HTTPS-only**,
   i.e. it must reference:
   - the type field `Microsoft.Storage/storageAccounts`, and
   - the alias
     `Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly`
     tested against `false` (`"equals": "false"`, or a `"notEquals": "true"`).
   Combine the two with `allOf` so only insecure storage accounts match.

Model it on a built-in like *"Secure transfer to storage accounts should be
enabled"*, but with a **deny** effect instead of audit.

(No subscription is touched — this task grades the JSON document itself.)
