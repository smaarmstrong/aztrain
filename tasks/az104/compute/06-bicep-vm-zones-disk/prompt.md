# Author Bicep for a zonal VM with a managed data disk

For resilience, a VM must be pinned to a specific availability zone, with a
zonal managed data disk in the same zone. Write `main.bicep` (in your
workspace) that a pipeline could deploy to produce exactly that.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `vmName`, a string `adminUsername`, a secure string
   `adminPublicKey`, a string `location` **defaulting to the resource group's
   location**, and a `zone` parameter selecting the availability zone.
2. A `Microsoft.Network/networkInterfaces` resource for the VM's NIC.
3. A `Microsoft.Compute/disks` (managed disk) resource:
   - SKU **`Standard_LRS`**, placed in the chosen **availability zone**
     (non-empty `zones`).
4. A `Microsoft.Compute/virtualMachines` resource on **`Standard_B1s`**:
   - Placed in the chosen **availability zone** (non-empty `zones`).
   - The managed disk above attached as a **data disk**.

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
