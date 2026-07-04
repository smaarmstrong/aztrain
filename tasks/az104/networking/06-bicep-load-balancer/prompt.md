# Author Bicep for a public Standard Load Balancer

A web tier behind a public VIP needs a load balancer that health-checks its
pool and forwards HTTP. Write `main.bicep` (in your workspace) that a pipeline
could deploy to stand up a Standard SKU public load balancer, wired end to end.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `location` **defaulting to the resource group's
   location**, used for all resources.
2. A `Microsoft.Network/publicIPAddresses` resource named `pip-lb` — **Standard
   SKU**, **Static** allocation (required for a Standard LB frontend).
3. Exactly one `Microsoft.Network/loadBalancers` resource named **`lb-web`**,
   **Standard SKU**, containing:
   - a **frontend IP configuration** named `frontend` bound to `pip-lb`
   - a **backend address pool** named `pool-web`
   - a **health probe** named `probe-http` — protocol **Tcp**, port **80**
   - a **load balancing rule** named `rule-http` that:
     - listens on frontend port **80**, forwards to backend port **80**,
       protocol **Tcp**
     - references the `frontend` frontend IP, the `pool-web` backend pool, and
       the `probe-http` probe

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/networking/06-bicep-load-balancer/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
