# Author Bicep for a Virtual Machine Scale Set

The web tier needs to run as a Virtual Machine Scale Set so it can scale out
under load. Write `main.bicep` (in your workspace) that a pipeline could
deploy to stand up the scale set on the cheapest instances.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `vmssName`, a string `adminUsername`, a secure string
   `adminPublicKey`, and a string `location` **defaulting to the resource
   group's location**.
2. A virtual network with at least one subnet for the instances to attach to.
3. Exactly one `Microsoft.Compute/virtualMachineScaleSets` resource:
   - SKU **`Standard_B1s`** with an initial **capacity of 2** instances.
   - An **upgrade policy** whose `mode` is `Automatic`.
   - A VM profile with a Linux configuration that **disables password
     authentication** and wires the SSH public key in from the
     `adminPublicKey` parameter.
   - OS disk backed by a managed disk of type **`Standard_LRS`**.

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
