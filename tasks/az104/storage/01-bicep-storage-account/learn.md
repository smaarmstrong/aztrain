THE IDEA

  This is your first Bicep task, so we'll start from zero.

  "Infrastructure as Code" (IaC) means: instead of clicking around the Azure
  portal to create a storage account, you DESCRIBE the account you want in a
  text file, check that file into git, and let a tool build it. The file is
  the source of truth — reviewable, repeatable, identical every time.

  Bicep is Azure's own language for that description. You write `.bicep`; a
  compiler turns it into ARM JSON (the verbose JSON template Azure actually
  deploys). You almost never read the JSON — but the grader does, because it
  checks the compiled result, so ANY Bicep that compiles to the right thing
  passes. There's no single "correct" wording.

  A Bicep file is mostly a list of resource declarations shaped like this:

    resource <symbolic-name> '<type>@<api-version>' = {
      name: 'what-azure-calls-it'
      location: 'uksouth'
      properties: { ... }
    }

  `<symbolic-name>` is just a handle YOU use elsewhere in the file. The
  `'<type>@<api-version>'` string is the Azure resource type and the dated
  version of its schema. Everything specific to the resource goes in
  `properties`.

---

  Nothing here touches the cloud — compiling Bicep is a purely LOCAL step, so
  the tutor can run it for you. First make sure the Bicep compiler is present
  (it ships inside the az CLI). This is safe and local; run it yourself:

```az
az bicep install
```

  Now let's compile a trivial file just to see the loop. This writes a tiny
  scratch template and compiles it to JSON on your screen — no resource is
  created, it's just the compiler:

```run
cat > _demo.bicep <<'BICEP'
param location string = resourceGroup().location
output where string = location
BICEP
az bicep build --file _demo.bicep --stdout
rm -f _demo.bicep
```

  See the JSON that came out? That `param ... = resourceGroup().location` line
  is a PARAMETER with a default: a value supplied at deploy time, here
  defaulting to the resource group's own region. `output` publishes a value
  back to whoever deployed the template. Those two ideas cover most of what
  this task asks for.

---

WHY IT MATTERS

  "Deploy everything through IaC" is how real teams work and a running theme
  of AZ-104: a storage account you can recreate from a reviewed file beats one
  someone hand-built and can't remember the settings of. And storage accounts
  are the classic security-review target — public blobs and weak TLS are how
  data leaks — so the settings this task asks for are the ones auditors check.

---

HOW TO DO IT

  Open your workspace `main.bicep` (its path is printed when you start the
  task) and declare ONE storage account. The pieces the task wants:

  - Two parameters: `storageAccountName` (a string, no default — the caller
    names the account) and `location` (a string DEFAULTING to
    `resourceGroup().location`, exactly like the demo above).
  - One `Microsoft.Storage/storageAccounts` resource whose `name` is the
    `storageAccountName` parameter and whose `location` is the `location`
    parameter. You reference a parameter just by writing its name.
  - `kind: 'StorageV2'` and an `sku: { name: 'Standard_LRS' }` (LRS =
    locally-redundant, the cheapest tier — fine for practice).
  - Inside `properties`, the security settings the review demands:
      minimumTlsVersion: 'TLS1_2'        // refuse old, weak TLS
      allowBlobPublicAccess: false       // no anonymous public blobs
      supportsHttpsTrafficOnly: true     // HTTPS only, no plaintext
  - One `output` named `blobEndpoint` set to
    `<symbolic-name>.properties.primaryEndpoints.blob` — you can read a
    property back off a resource you declared using its symbolic name.

  Write it, then compile to check it's valid (local, safe — run it yourself
  or let the tutor). Replace the path if yours differs:

```run
az bicep build --file "$AZTRAIN_WS/main.bicep" --stdout >/dev/null && echo "compiles OK" || echo "not valid yet — read the error above"
```

  A clean compile means the syntax is right; the grader then checks the
  values.

---

CHECK IT WORKED

  Grade it:  aztrain check

  The grader compiles your file and asserts each property on the storage
  account in the resulting ARM JSON. Because it reads the END STATE, your
  Bicep can look nothing like the reference solution and still pass — only the
  compiled result matters.

---

GOTCHAS

  - `name` (what Azure calls the account, from the parameter) is NOT the
    same as the symbolic name (your in-file handle). Both exist; don't
    conflate them.
  - The three security properties live INSIDE `properties: { }`, not at the
    top level of the resource.
  - `location` must come from the parameter, not a hard-coded 'uksouth' —
    the task checks the default is `resourceGroup().location`.
  - Stuck? `aztrain solution` shows one correct file — but write yours first;
    the skill is describing a resource, not copying one.
