# Author Bicep for a VNet with two subnets

Your platform team lays down every landing-zone network as IaC. Write
`main.bicep` (in your workspace) that a pipeline could deploy into any resource
group to stand up a virtual network carved into a web tier and a data tier.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `location` **defaulting to the resource group's
   location**, used as the VNet's location.
2. Exactly one `Microsoft.Network/virtualNetworks` resource named `vnet-app`.
3. The VNet's address space is **`10.20.0.0/16`**.
4. It has **exactly two subnets**:
   - `snet-web` with prefix **`10.20.1.0/24`**
   - `snet-data` with prefix **`10.20.2.0/24`**
   (Declare them however you like — inline in the VNet's `subnets` array or as
   child `subnets` resources; the grader reads the compiled ARM either way.)
5. An output named `subnetIds` that is an **array** of the two subnet resource
   IDs.

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/networking/02-bicep-vnet-subnets/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
