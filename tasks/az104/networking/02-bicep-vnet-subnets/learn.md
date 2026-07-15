THE IDEA

  A virtual network (VNet) is your own private IP address space in Azure.
  Inside it you carve out SUBNETS — smaller ranges, one per tier of your app
  (say a web tier and a data tier) — so you can control traffic between them
  later. This task describes one VNet with two subnets in Bicep.

  The only genuinely new thing here is CIDR notation, so let's make sure it's
  not a mystery.

  An address like `10.20.0.0/16` means: the first 16 bits are fixed (the
  network part, `10.20.`) and the remaining bits are free for hosts. So
  `10.20.0.0/16` covers everything from 10.20.0.0 to 10.20.255.255 — a big
  block. A `/24` fixes 24 bits (`10.20.1.`), leaving just the last number
  free: 256 addresses, 10.20.1.0 to 10.20.1.255 — a small block.

  So a /16 VNet neatly contains many /24 subnets. `10.20.1.0/24` and
  `10.20.2.0/24` are two non-overlapping /24s that both sit inside
  `10.20.0.0/16`. That's exactly the shape this task wants.

---

WHY IT MATTERS

  Networking is a big slice of AZ-104, and every VNet task starts here:
  choosing a private address space and subnetting it. Get the ranges wrong —
  overlapping subnets, or subnets outside the VNet's space — and nothing
  deploys. Peering two VNets later (a follow-on task) also fails if their
  address spaces collide, so picking clean, non-overlapping ranges is a habit
  worth building now.

---

HOW TO DO IT

  In your workspace `main.bicep`:

  - One parameter `location` (string, defaulting to
    `resourceGroup().location`) — same pattern as every Bicep task.
  - One `Microsoft.Network/virtualNetworks` resource named `vnet-app` whose
    `properties.addressSpace.addressPrefixes` contains `'10.20.0.0/16'`.
  - Two subnets. The simplest way is INLINE, as a list under the VNet's
    `properties.subnets`, each with a `name` and a
    `properties.addressPrefix`:
        snet-web  -> 10.20.1.0/24
        snet-data -> 10.20.2.0/24
    (Declaring them as separate child resources also works — the grader
    accepts either — but inline is easiest to read for two subnets.)
  - An `output subnetIds array = [ ... ]` — the grader only checks it's an
    array; use `resourceId(...)` for each subnet, or reference them, whatever
    compiles.

  Compile to check validity — local and safe, so let the tutor run it or type
  it yourself. No network is created:

```run
az bicep build --file "$AZTRAIN_WS/main.bicep" --stdout >/dev/null && echo "compiles OK" || echo "not valid yet — read the error above"
```

---

CHECK IT WORKED

  Grade it:  aztrain check

  It compiles your file and asserts: one VNet named vnet-app, address space
  10.20.0.0/16, exactly two subnets with the right names and prefixes, and an
  array output. Inline or child-resource subnets both pass — it reads the end
  state, not your style.

---

GOTCHAS

  - Subnet ranges must sit INSIDE the VNet's address space. 10.20.1.0/24 and
    10.20.2.0/24 are inside 10.20.0.0/16; something like 10.30.1.0/24 is not
    and won't validate.
  - Subnets must not overlap each other. /24s that differ in the third octet
    (1 vs 2) don't.
  - Names matter here (`vnet-app`, `snet-web`, `snet-data`) — the grader
    looks for them by name.
  - This is a LOCAL task: you're authoring and compiling only, never
    deploying, so it costs nothing and touches no subscription.
