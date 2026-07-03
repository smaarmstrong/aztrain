# Fix the NSG so HTTPS reaches the web subnet (HTTP stays blocked)

During a security sweep a colleague slapped a blanket deny on the web tier's
network security group — and took the public HTTPS endpoint down with it.

Setup has created (in your `rg-aztrain-...` resource group, all free
resources) an NSG called **`nsg-web`** whose current rules block ALL web
traffic from the Internet.

## Requirement

Change `nsg-web`'s rules so that, for traffic **from the Internet, Inbound**:

- **TCP 443 (HTTPS) is allowed**
- **TCP 80 (HTTP) stays denied**

How you get there is up to you — add rules, narrow the offending one, or
both. The grader simulates NSG evaluation (priority order, first match wins,
default rules last) against those two flows, so **any rule set with the right
behaviour passes**.

Useful commands:

```sh
az network nsg rule list -g $RG --nsg-name nsg-web -o table
az network nsg rule create --help
az network nsg rule update --help
```

(`$RG` is printed by `aztrain start`; it's also in `az group list -o table`
as the only `rg-aztrain-*` group for this task.)
