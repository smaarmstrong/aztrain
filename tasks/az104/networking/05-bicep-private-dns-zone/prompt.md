# Author Bicep for a private DNS zone with an A record and a VNet link

An internal app needs a private, VNet-scoped DNS name that never resolves on
the public Internet. Write `main.bicep` (in your workspace) that a pipeline
could deploy to stand up the zone, an A record, and a link to a virtual
network.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. An existing `Microsoft.Network/virtualNetworks` resource named `vnet-app`
   (address space `10.30.0.0/16`) that the zone will be linked to. Location may
   default to the resource group's location.
2. A `Microsoft.Network/privateDnsZones` resource named
   **`corp.internal`**. (Private DNS zones are global — `location` is
   `'global'`.)
3. An A record — a `Microsoft.Network/privateDnsZones/A` resource — named
   **`app`** in that zone, with:
   - TTL **`3600`**
   - a single A record whose `ipv4Address` is **`10.30.1.10`**
4. A `Microsoft.Network/privateDnsZones/virtualNetworkLinks` resource named
   **`link-vnet-app`** that links the zone to `vnet-app` (its
   `virtualNetwork.id` points at `vnet-app`).

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/networking/05-bicep-private-dns-zone/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
