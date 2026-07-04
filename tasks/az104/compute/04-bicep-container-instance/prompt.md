# Author Bicep for a public Azure Container Instance

You need a small always-on container reachable from the Internet — the
quickest way is Azure Container Instances. Write `main.bicep` (in your
workspace) that a pipeline could deploy to run one public container with
sized CPU/memory.

Requirements — graded on the **compiled ARM template**, so any Bicep style
that produces the right result passes:

1. Parameters: a string `containerGroupName` and a string `location`
   **defaulting to the resource group's location**.
2. Exactly one `Microsoft.ContainerInstance/containerGroups` resource with
   `osType` Linux, holding **at least one container**:
   - The container requests **1 CPU** and **1 GB of memory**
     (`resources.requests.cpu` = 1, `memoryInGB` = 1).
   - The container exposes **port 80** (TCP).
3. The group has a **public IP address** (`ipAddress.type` = `Public`) that
   opens **port 80**.

Check your work compiles as you go:

```sh
az bicep build --file main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
