# Fix the black-holed subnet by repairing its user-defined route

A change to the web tier's routing has cut it off from the Internet. Setup has
created (in your `rg-aztrain-...` resource group, all free resources):

- a VNet **`vnet-app`** (`10.40.0.0/16`) with a subnet **`snet-web`**
  (`10.40.1.0/24`)
- a route table **`rt-web`** associated with `snet-web`
- inside `rt-web`, a user-defined route named **`default`** for destination
  **`0.0.0.0/0`** whose next hop type is **`None`** — a black hole. All egress
  from the subnet is silently dropped.

## Requirement

Repair routing for `snet-web` so that its default route (`0.0.0.0/0`) sends
traffic to the **Internet** next hop again, while the route table stays
associated with the subnet.

How you get there is up to you — update the existing `default` route's next hop
type to `Internet`, replace it, or otherwise arrange `rt-web` so its
`0.0.0.0/0` route resolves to `Internet`. The grader reads the route table's
end state, so **any arrangement with the right behaviour passes**.

Useful commands:

```sh
az network route-table route list -g $RG --route-table-name rt-web -o table
az network route-table route update --help
az network vnet subnet show -g $RG --vnet-name vnet-app -n snet-web \
  --query routeTable.id -o tsv
```

(`$RG` is printed by `aztrain start`; it's also in `az group list -o table`
as the only `rg-aztrain-*` group for this task.)
