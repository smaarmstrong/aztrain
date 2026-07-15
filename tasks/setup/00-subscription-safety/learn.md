THE IDEA

  Before you run a single training task that touches Azure, you build one
  safety rail: a SEPARATE Azure subscription that this trainer is pinned to,
  so nothing you do here can ever reach a real/work tenant by accident.

  Three words worth knowing first:

    tenant         your organisation's identity boundary (one directory of
                   users). Your work login lives in a work tenant.
    subscription   a billing + resource container INSIDE a tenant. Everything
                   you create (a VM, a storage account) lives in one.
    resource group a labelled box inside a subscription that holds related
                   resources so you can manage/delete them together.

  aztrain refuses to touch the cloud unless the "active" subscription matches
  a GUID you save in ~/.config/aztrain/subscription. That file is the pin.

  IMPORTANT: this whole trainer NEVER runs `az` for you. Every command below
  is one YOU run, so you can see exactly what touches your account. When a
  step says "Run this yourself", the tutor will show it and — if you like —
  drop you into a shell to type it, but it will not fire it on your behalf.

---

WHY IT MATTERS

  The number-one way people get hurt in cloud training is running a tutorial
  command against the wrong subscription — deleting a resource group that
  turns out to be production, or racking up spend on the company account.

  A dedicated subscription with a small budget makes that structurally
  impossible: the worst case is a few pounds on an account that holds nothing
  but throwaway practice resources. Cheap insurance.

---

HOW TO DO IT — 1. a personal account

  If you don't already have a personal Azure account, sign up at
  https://azure.microsoft.com/free in a PRIVATE browser window (so you don't
  reuse a work login). You get free credit for 30 days; a card is needed for
  identity only and isn't charged during the free period.

  Come back here once you can log in as that personal account.

---

HOW TO DO IT — 2. log in WITHOUT disturbing a work login

  `az login` adds the new tenant alongside any you already have and changes
  your default subscription — so check what you've got before and after.

  Run this yourself (device-code login keeps it in a browser you control):

```az
az login --use-device-code
```

  Then list what az can now see, and read it carefully — which row is the new
  PERSONAL subscription?

```az
az account list --query "[].{name:name, id:id, isDefault:isDefault}" -o table
```

  `--query` there is JMESPath (a little query language for JSON that az has
  built in): `[]` walks the list, and `{name:name, id:id, ...}` reshapes each
  item into just the fields we want. `-o table` prints it as a grid.

---

HOW TO DO IT — 3. make the personal subscription active, then PIN it

  Set the personal subscription as the active one (paste its id from above):

```az
az account set --subscription <the-personal-subscription-id>
```

  Now write its GUID to the pin file. `az account show --query id -o tsv`
  prints just the active subscription's id as a bare string (`-o tsv` = no
  quotes/formatting), which we redirect into the file:

```az
mkdir -p ~/.config/aztrain
az account show --query id -o tsv > ~/.config/aztrain/subscription
cat ~/.config/aztrain/subscription
```

  That last `cat` should show your TRAINING subscription's GUID. From now on
  every cloud task checks the active subscription against this file.

---

HOW TO DO IT — 4. a budget with an alert (pounds, not hundreds)

  Create a small monthly budget so a mistake is capped and you get warned:

```az
SUB=$(cat ~/.config/aztrain/subscription)
az consumption budget create \
  --budget-name aztrain-budget --amount 10 \
  --category cost --time-grain monthly \
  --start-date "$(date +%Y-%m-01)" \
  --end-date "$(date -d '+2 years' +%Y-%m-01)"
```

  Then add the ALERT in the portal (Cost Management -> Budgets ->
  aztrain-budget): 50% and 90%, to your email. Alert conditions for
  consumption budgets are portal-only. A budget without an alert is a
  tripwire with no bell — do it now.

---

HOW TO DO IT — 5. a service principal scoped to THIS subscription only

  Later AZ-400 tasks (OIDC, pipelines) need a non-human identity that cannot
  reach anything but this subscription:

```az
az ad sp create-for-rbac --name aztrain-sp \
  --role Contributor --scopes "/subscriptions/$SUB"
```

  Store the output in a PASSWORD MANAGER — never in this repo, never in a
  file under this clone. Nothing here should ever contain a secret.

---

CHECK IT WORKED

  Run this yourself — it prints who you currently are and where. (Even a
  read-only `az account show` has to authenticate, so aztrain leaves it to
  you.) Confirm the subscription id matches your pin file:

```az
az account show --query "{subscription:name, id:id, user:user.name}" -o table
```

  If that id equals the GUID in ~/.config/aztrain/subscription, the rail is
  up. Grade it with:  aztrain check

---

GOTCHAS

  - The pin is a SAFETY feature, not a nuisance: if a task says "active
    subscription is not the pinned one", that's the rail doing its job. Fix it
    with `az account set -s <pin>`, don't disable the check.
  - Do NOT commit the service-principal output, the pin, or any credential.
  - Tearing down: every live task's resources live in rg-aztrain-<task>;
    remove them with `aztrain teardown <id>` or `aztrain teardown --all`.
    That is the only command in the whole trainer that deletes anything.
