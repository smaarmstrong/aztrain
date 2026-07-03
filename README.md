# aztrain

A console trainer for the Azure certification pathway — **AZ-104 (Azure
Administrator)** then **AZ-400 (DevOps Engineer)** — that teaches by **doing**,
not flashcards. Sibling of [redhat](https://github.com/smaarmstrong/redhat),
[pytrain](https://github.com/smaarmstrong/pytrain) and ctrain: same runner
DNA, same XP + streak, same fail-before/pass-after selftest discipline.

Every task is a job with a graded end state:

- **local** (most tasks, free, offline): author Bicep graded on the compiled
  ARM JSON; write KQL graded against canned fixtures by a deterministic
  KQL-subset engine; pipeline YAML (GitHub Actions & Azure Pipelines) graded
  structurally; policy/RBAC JSON authoring.
- **whatif** (needs the training sub, deploys nothing, ~free):
  `az deployment group what-if` proves your template WOULD create the right
  resources.
- **live** (the redhat-style meat): `setup.sh` provisions a small broken/
  incomplete state in a disposable resource group; you do the exam-shaped job
  with the real `az` CLI; `grade.sh` asserts the END STATE with read-only
  queries — any correct fix passes.

Coverage mirrors the **official exam study guides**: every checkbox in
[docs/objectives.md](docs/objectives.md) is a verbatim skill bullet, mapped to
a task domain — trainer progress IS cert progress.

## Safety & cost rails (read before anything else)

- Cloud-touching tasks **refuse to run** unless the active az subscription
  equals the one pinned in `~/.config/aztrain/subscription`. Do
  `./aztrain start setup/00-subscription-safety` first: it walks you through a
  dedicated personal subscription, a £10 budget + alert, the pin file, and a
  service principal scoped to that subscription only. Your work tenant is
  structurally unreachable.
- Every live task lives in its own resource group `rg-aztrain-<task>`, created
  by its setup and destroyed **only** by `./aztrain teardown <id|--all>`. The
  runner nags at start-up if any `rg-aztrain-*` groups linger.
- Tasks declare `est_cost: free | pennies | paid` and pin the cheapest SKUs;
  anything `paid` refuses to start without an explicit `--i-am-paying`.
- Graders only ever **read** cloud state.

## Setup

Requires Python ≥ 3.11 and the [az CLI](https://aka.ms/azure-cli); Bicep tasks
also need `az bicep install`. Or open the repo in the devcontainer, which
ships both.

```sh
git clone git@github.com:smaarmstrong/aztrain.git && cd aztrain
./aztrain start setup/00-subscription-safety   # the safety rail — do it first
```

## The loop

```sh
./aztrain list                # tasks by track/domain, with your status
./aztrain start <id>          # provision (live) / scaffold, show the spec
# ... do the job: edit workspace files, or drive az against the task's RG ...
./aztrain check <id>          # grade the end state; XP + streak on first pass
./aztrain solution <id>       # a reference answer (any correct one passes)
./aztrain teardown <id|--all> # destroy rg-aztrain-* groups when done
./aztrain status              # XP, streak, per-domain progress bars
```

`<id>` is `az104/networking/01-nsg-allow-https` or just a unique
`01-nsg-allow-https` / `nsg-allow-https`.

## Selftest

```sh
./selftest.py            # structure + coverage + fail-before/pass-after for
                         # every local task (CI runs exactly this)
./selftest.py --live     # exercises whatif/live tasks against the PINNED sub:
                         # setup → grade(must FAIL) → solution → grade(must
                         # PASS), teardown guaranteed even on failure
```

## Authoring tasks

See [docs/authoring.md](docs/authoring.md) — including the non-negotiable
review checklist for live tasks' cost rails.
