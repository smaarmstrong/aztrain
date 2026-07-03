# Create and pin a dedicated training subscription

Every cloud-touching task in this trainer refuses to run unless the active
`az` subscription matches the one pinned in `~/.config/aztrain/subscription`.
This task builds that rail. **Nothing else works until it passes**, and that is
deliberate: it makes it impossible for a training task to touch a work tenant.

## 1. Create a personal Azure account (skip if you have one)

- Go to <https://azure.microsoft.com/free> **in a private browser window** (so
  you don't accidentally reuse a work login) and sign up with a **personal**
  Microsoft account.
- The free account gives ~£150/$200 credit for 30 days plus a set of
  always-free services; after 30 days you convert to pay-as-you-go (you are
  only charged for what you use — this trainer pins free/cheapest SKUs and
  nags you to tear down).
- You will need a credit card for identity verification; it is not charged
  during the free period.

## 2. Log in to that account with az — without disturbing your work login

```sh
az login --use-device-code
```

Pick the **personal** account in the browser. If you use az for work, note
that `az login` adds the new tenant alongside existing ones and changes the
default subscription — check `az account list -o table` and make sure you know
which is which before doing anything else.

Find your new subscription's ID:

```sh
az account list --query "[].{name:name, id:id, tenant:tenantId}" -o table
az account set -s <the-new-subscription-id>
```

## 3. Pin it

```sh
mkdir -p ~/.config/aztrain
az account show --query id -o tsv > ~/.config/aztrain/subscription
cat ~/.config/aztrain/subscription   # sanity-check: the TRAINING sub's GUID
```

## 4. Budget with an alert, so a mistake costs pounds, not hundreds

Create a monthly budget named `aztrain-budget` of **10** (in your billing
currency) on the subscription:

```sh
SUB=$(cat ~/.config/aztrain/subscription)
az consumption budget create \
  --budget-name aztrain-budget --amount 10 \
  --category cost --time-grain monthly \
  --start-date "$(date +%Y-%m-01)" \
  --end-date "$(date -d '+2 years' +%Y-%m-01)"
```

Then in the portal (Cost Management → Budgets → aztrain-budget) add an **alert
at 50% and 90% with your email** — alert conditions are portal-only for
consumption budgets. Do it now; a budget without an alert is a tripwire
without a bell.

## 5. A service principal scoped to this subscription only

Later AZ-400 tasks (OIDC federation, pipelines) need an identity that *cannot*
reach anything but the training subscription:

```sh
az ad sp create-for-rbac --name aztrain-sp \
  --role Contributor --scopes "/subscriptions/$SUB"
```

Store the output somewhere safe (a password manager, NOT this repo — nothing
under this clone should ever contain a secret).

## 6. Grade it

```sh
aztrain check setup/00-subscription-safety
```

The grader only reads state. It asserts: the pin file holds the active
subscription's GUID, the budget exists at ≤ 10, and `aztrain-sp` exists with a
role assignment scoped to this subscription and no wider.
