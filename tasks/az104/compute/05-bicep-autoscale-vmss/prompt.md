# Author Bicep autoscale settings for a scale set

The web-tier scale set needs to grow and shrink with CPU load instead of
being resized by hand. Write `main.bicep` (in your workspace) that defines
the scale set **and** an autoscale profile that drives it off CPU.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `vmssName` and a string `location` **defaulting to
   the resource group's location**.
2. A `Microsoft.Compute/virtualMachineScaleSets` resource on SKU
   `Standard_B1s` for the autoscale profile to target.
3. A `Microsoft.Insights/autoscaleSettings` resource:
   - `enabled` true, and `targetResourceUri` pointing at the scale set.
   - A profile with **capacity minimum 2, maximum 10, default 2**.
   - At least one rule whose `metricTrigger` watches the **`Percentage CPU`**
     metric and whose `scaleAction` changes the instance count (a
     scale-**out** rule when CPU is high).

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
