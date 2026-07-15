THE IDEA

  You've described a single resource in Bicep before (the storage account).
  A virtual machine is the same idea with one new wrinkle: a VM never stands
  alone. To exist it needs a network interface (a NIC) to attach to. So this
  task is really TWO resources — a NIC and a VM — with the VM pointing at the
  NIC.

  When one resource refers to another, you use the other's symbolic name.
  Writing `nic.id` in the VM makes Bicep (a) insert the NIC's resource id and
  (b) work out that the NIC must be created first. You get correct ordering
  for free just by referencing — no manual "dependsOn" needed.

---

  Two more concepts this task introduces:

  A SECURE parameter. An SSH public key isn't secret, but credentials-shaped
  inputs should be marked `@secure()` so their values never get logged or
  echoed into deployment history. You write the decorator on its own line
  above the parameter:

    @secure()
    param adminPublicKey string

  An IMAGE REFERENCE. A VM boots from an OS image identified by four fields —
  publisher / offer / sku / version — e.g. Canonical's Ubuntu 22.04. You
  copy these from the docs; you don't memorise them.

---

WHY IT MATTERS

  "Deploy a VM by SSH key, not a password" is both an exam objective and basic
  hygiene: password auth on a public VM is brute-forced within minutes.
  Disabling it (`disablePasswordAuthentication: true`) and supplying a key is
  the secure default. And picking Standard_B1s — a tiny, cheap burstable size
  — is the cost-awareness this trainer keeps drilling: never provision a
  monster when a B1s teaches the same skill.

---

HOW TO DO IT

  In your workspace `main.bicep`, declare:

  Parameters: `vmName` (string), `adminUsername` (string),
  `adminPublicKey` (string, marked `@secure()`), and `location` (string
  defaulting to `resourceGroup().location`).

  A NIC — `Microsoft.Network/networkInterfaces` — with one ipConfiguration
  using dynamic private IP allocation. (Copy the shape from the docs link in
  the starter file; the exact ipconfig name doesn't matter.)

  A VM — `Microsoft.Compute/virtualMachines` — whose `properties` set:
    - hardwareProfile.vmSize: 'Standard_B1s'
    - osProfile with adminUsername, and a linuxConfiguration that sets
      disablePasswordAuthentication: true and supplies the public key
      (path /home/<adminUsername>/.ssh/authorized_keys, keyData the parameter)
    - storageProfile.imageReference for Ubuntu, and an osDisk with
      managedDisk.storageAccountType: 'Standard_LRS'
    - networkProfile.networkInterfaces referencing your NIC by `nic.id`

  Compile as you go — local and safe, so the tutor can run it (or type it
  yourself). It only checks validity; no VM is created:

```run
az bicep build --file "$AZTRAIN_WS/main.bicep" --stdout >/dev/null && echo "compiles OK" || echo "not valid yet — read the error above"
```

  Nothing here deploys. Authoring and compiling Bicep is entirely offline;
  actually creating the VM would be a live task (and would cost money), which
  this is not.

---

CHECK IT WORKED

  Grade it:  aztrain check

  It compiles your template and asserts the VM size, the managed-disk SKU,
  that password auth is off, that the key is wired from your @secure()
  parameter, and that the VM is attached to a NIC — behaviour, not wording.

---

GOTCHAS

  - Forgetting the NIC (or not referencing it from the VM) is the classic
    miss — a VM with no network interface won't validate.
  - `@secure()` goes on the parameter DECLARATION, not on its use.
  - Keep the size Standard_B1s. A bigger size still compiles but misses the
    point (and, in a live version, your budget).
  - The reference solution is one shape; `aztrain solution` shows it, but any
    template that compiles to the same facts passes.
