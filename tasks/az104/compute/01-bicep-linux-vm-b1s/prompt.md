# Author Bicep for a cheap, key-only Linux VM

Finance flagged the dev VMs as too expensive and security flagged them for
allowing password logins. Write `main.bicep` (in your workspace) that a
pipeline could deploy to produce a small Linux VM that fixes both: the
cheapest burstable size and SSH-key-only auth.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `vmName`, a string `adminUsername`, a secure string
   `adminPublicKey`, and a string `location` **defaulting to the resource
   group's location**.
2. A `Microsoft.Network/networkInterfaces` resource for the VM's NIC.
3. Exactly one `Microsoft.Compute/virtualMachines` resource:
   - VM size **`Standard_B1s`** (cheapest burstable SKU).
   - OS disk backed by a managed disk of type **`Standard_LRS`**.
   - A Linux configuration with **password authentication disabled**
     (`disablePasswordAuthentication` true) and the SSH public key wired in
     from the `adminPublicKey` parameter.
   - Attached to the NIC above (via `networkProfile`).

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
