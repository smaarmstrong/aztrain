# Author Bicep to peer two virtual networks

A hub-and-spoke design needs the spoke's traffic to transit the hub. Write
`main.bicep` (in your workspace) that a pipeline could deploy to stand up two
virtual networks and peer the spoke to the hub.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. A string parameter `location` **defaulting to the resource group's
   location**, used for both VNets.
2. Two `Microsoft.Network/virtualNetworks` resources:
   - `vnet-hub` with address space **`10.0.0.0/16`**
   - `vnet-spoke` with address space **`10.1.0.0/16`**
3. A `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` resource named
   **`spoke-to-hub`** that peers **from `vnet-spoke` to `vnet-hub`**:
   - its `remoteVirtualNetwork` points at `vnet-hub`'s resource ID
   - `allowForwardedTraffic` is **true**
   - `allowVirtualNetworkAccess` is **true**

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/networking/03-bicep-vnet-peering/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
