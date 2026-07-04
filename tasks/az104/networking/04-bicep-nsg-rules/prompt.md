# Author Bicep for an NSG that allows HTTPS and denies HTTP

The live NSG task fixed rules with the `az` CLI. This time your team wants the
web tier's network security group defined as IaC. Write `main.bicep` (in your
workspace) that a pipeline could deploy to create the NSG with the right rules
baked in.

Requirements — graded on the **compiled ARM template**. The grader feeds your
compiled security rules through the same NSG evaluator Azure uses (priority
order, first match wins, default rules last), so **any rule set with the right
behaviour passes** — you choose the priorities and shapes.

1. A string parameter `location` **defaulting to the resource group's
   location**.
2. Exactly one `Microsoft.Network/networkSecurityGroups` resource named
   **`nsg-web`**.
3. Its rules must produce this behaviour, for **Inbound** traffic **from the
   Internet**:
   - **TCP 443 (HTTPS) is ALLOWED**
   - **TCP 80 (HTTP) is DENIED**
   - **TCP 22 (SSH) is DENIED**
4. At least one of your rules must be an explicit `Allow` and at least one an
   explicit `Deny` (i.e. don't lean solely on the default deny — author real
   rules).

Check your work compiles as you go:

```sh
az bicep build --file workspace/az104/networking/04-bicep-nsg-rules/main.bicep --stdout
```

(No subscription is touched — this task grades the template itself.)
