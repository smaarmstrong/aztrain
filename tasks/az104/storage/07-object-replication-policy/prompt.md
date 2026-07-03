# Write an object replication policy from source to destination

Your web app writes user uploads to a `uploads` container in a storage account
in UK South. A read-only analytics stack in another region needs a copy of
every new blob, asynchronously, without the app doing any extra work. That is
**object replication**: a policy on the destination account pulls blobs from a
source container into a destination container.

Author the replication policy JSON in your workspace as `or-policy.json`. This
is the document you would pass to
`az storage account or-policy create --policy @or-policy.json ...` on the
**destination** account, so its shape must match the object-replication policy
schema.

Requirements — graded structurally on the parsed JSON, so any equivalent
formatting passes:

1. A `sourceAccount` and a `destinationAccount` field (the two accounts the
   policy links). The value `default` is acceptable when the account is
   inferred at create time, but both keys must be present.
2. A `rules` array with at least one rule.
3. That rule sets:
   - `sourceContainer` to `uploads`
   - `destinationContainer` to `uploads-replica`

Object replication reference:
https://learn.microsoft.com/azure/storage/blobs/object-replication-overview

Nothing is deployed — this task grades the policy document itself.
