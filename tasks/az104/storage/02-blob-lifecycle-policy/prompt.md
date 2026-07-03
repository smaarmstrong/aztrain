# Write a blob lifecycle management policy that tiers then deletes

Storage costs on your `logs` container are creeping up. Finance wants old log
blobs pushed to cheaper storage automatically and eventually deleted, with no
one touching the portal each month.

Author the lifecycle management policy JSON in your workspace as `policy.json`.
This is exactly the document you would pass to
`az storage account management-policy create --policy @policy.json ...`, so
its shape must match the Azure management-policy schema.

Requirements — graded structurally on the parsed JSON, so any equivalent
formatting passes:

1. A top-level `rules` array containing at least one **enabled** rule of type
   `Lifecycle`.
2. The rule's filter targets **block blobs** (`blobTypes` includes
   `blockBlob`).
3. Under the rule's actions for `baseBlob`:
   - `tierToCool` when the blob was **last modified more than 30 days ago**
     (`daysAfterModificationGreaterThan` == 30).
   - `delete` when the blob was **last modified more than 365 days ago**
     (`daysAfterModificationGreaterThan` == 365).

Nothing is deployed — this task grades the policy document itself. The
management-policy schema lives at
https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview
