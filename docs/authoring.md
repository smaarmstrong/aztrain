# Authoring tasks

A task is a directory `tasks/<track>/<domain>/<nn-name>/` (domains must match
a `domain-dir` declared in [objectives.md](objectives.md); `tasks/setup/` is
the one exception). The **leaf name must be unique repo-wide** — it names the
task's resource group.

## Files

| file | required | purpose |
|---|---|---|
| `meta.json` | always | see schema below — a dir without one FAILS selftest |
| `prompt.md` | always | the job, exam-shaped: a scenario + requirements, never "run this command" |
| `grade.sh` | always | asserts the END STATE; sources `lib/common.sh`; **read-only** |
| `solution/` or `solution.sh` | always | file tree (local) or script (live) — proof one correct answer exists |
| `starter/` | local, optional | scaffold copied to the learner's workspace |
| `setup.sh` | whatif/live | provisions the starting state, idempotent, only inside `$AZTRAIN_RG` |
| `fixture.json`, `expected.json` | katas | canned `az`/Log-Analytics output checked into the repo |
| `learn.md` | optional | the tutor lesson shown by `aztrain learn` (see below) |

## meta.json

```json
{
  "title": "Fix the NSG so HTTPS reaches the web subnet",
  "objective": "<verbatim bullet from docs/objectives.md>",
  "est_min": 10,
  "difficulty": 2,
  "kind": "local | whatif | live",
  "est_cost": "free | pennies | paid",
  "tags": ["networking"]
}
```

XP by difficulty: 1→10, 2→15, 3→25, 4→40, 5→60.

## Environment given to setup/grade/solution scripts

`AZTRAIN_REPO`, `AZTRAIN_TASK_DIR`, `AZTRAIN_WS` (the learner's workspace,
also the cwd), `AZTRAIN_RG` (`rg-aztrain-<leaf>`), `AZTRAIN_LOCATION`
(default `uksouth`), `AZTRAIN_TASK_ID`.

## Quality bars (all tasks)

- **End state / behaviour only.** Any correct fix passes: simulate semantics
  (e.g. `tools/nsgsim.py` evaluates NSG rules like Azure does) rather than
  matching one expected command's fingerprints. Never grade history, style,
  or *how* the learner got there.
- **Deterministic.** Local tasks grade against fixtures checked into the
  repo; fixture "now" is frozen via the `@now` key (`tools/kqlmini.py` errors
  on `ago()` without it). Live graders assert properties, never timings.
- **Fail-before/pass-after.** The grader must FAIL on the starter/fresh setup
  and PASS after the reference solution — `./selftest.py` (local) and
  `./selftest.py --live` (cloud) prove both directions.
- **No secrets** anywhere in the repo — prompts must route credentials to a
  password manager, and AZ-400 secret-hygiene tasks grade *by inspection*
  that none landed in YAML or git history.

## `learn.md` (optional lesson)

The interactive lesson `aztrain learn` walks a learner through *before* they
attempt the task — for people meeting the material for the first time, not just
being tested on it. Optional: with no `learn.md`, `learn` falls back to showing
the prompt and pointing at `solution`. `aztrain train` never needs it.

It's read as a **tutor script**: plain, readable prose plus two markers —

- A line that is exactly `---` is a **pause**: everything above it prints, then
  the tutor waits ("Enter to continue") before going on. Use it to break the
  lecture into digestible beats.
- A fenced **run block** is a step to try. Three fences, differing only in
  whether the tutor may execute it:

  | fence | meaning |
  |---|---|
  | ` ```run ` | a step the tutor MAY run for the learner — **only if it classifies as local & read-only** |
  | ` ```run-manual ` / ` ```az ` | **always present-only** — shown for the learner to run themselves |

  Everything else prints as-is, so write plain text (`$ command` for
  illustrative snippets), not heavy Markdown.

### Azure safety — the divergence from the redhat/pytrain tutors

Those tutors run every block on a throwaway machine. **aztrain runs on the
learner's real box against their real subscription**, so a run block **must
never auto-execute anything that authenticates to Azure, mutates cloud
resources, or costs money.**

This is enforced **safe-by-default in the runner**, not left to author
discipline: even inside a plain ` ```run ` fence, `run_lesson` re-classifies the
block and refuses to auto-run it if it sees anything but local, read-only work.
Only a tight allow-list auto-runs — `az --version`, `az bicep build|version|
lint|format|decompile`, and non-`az` shell (`cat`, `python3 tools/…`, heredocs).
Anything else — `az login`, `az account …`, `az group/deployment … create`,
`az bicep install`, `azd`/`terraform`/`kubectl`, `bicep deploy` — is **presented
only**: the learner runs it themselves, and `t` opens an interactive shell (with
Tab autocompletion) under their own `az login`.

Authoring rules that follow:

- Put **cloud commands** (`az login`, provisioning, deployments) in ` ```az `
  blocks and phrase the prose as "Run this yourself" — never "the tutor runs
  this". They are teaching text, executed only by the learner.
- Only ` ```run ` blocks that are genuinely local — compiling Bicep with
  `az bicep build`, running a `tools/` grader against a fixture, writing a
  scratch file with a heredoc — may rely on auto-run.
- For **local (Bicep/KQL) tasks**, `learn` scaffolds the workspace first so
  `$AZTRAIN_WS/main.bicep` exists to compile. For **cloud tasks it provisions
  nothing** — teaching is read-only; the learner triggers `setup.sh` via
  `aztrain start`.

House style (same five beats as the sibling trainers), interleaved with `---`
pauses and run blocks: **THE IDEA · WHY IT MATTERS · HOW TO DO IT · CHECK IT
WORKED · GOTCHAS**. Teach the *concept and the flags inline* — assume the
learner has never seen `--query`/JMESPath or a Bicep resource block before. See
`tasks/setup/00-subscription-safety/` (the safe cloud showcase) and
`tasks/az104/storage/01-bicep-storage-account/` (Bicep from zero) for worked
examples.

## Cost rails for whatif/live tasks (non-negotiable, reviewed in every PR)

1. `setup.sh` starts with `ensure_rg` and creates **only** inside
   `$AZTRAIN_RG`. It must be idempotent (re-running start = clean state).
2. `grade.sh` only READS (`az ... show/list/--query`). Selftest greps for
   `az ... delete` in graders and fails; review catches the subtler cases.
3. Nothing ever deletes a resource group except `aztrain teardown` and the
   guaranteed-teardown in `selftest.py --live`.
4. Pin the cheapest SKU that teaches the skill: B1s VMs, Consumption
   functions, Standard_LRS, Basic/Free tiers. NSGs, VNets, RGs, identities,
   policies are free — prefer scenarios built from them.
5. `est_cost` honesty: `free` = no billable resource; `pennies` = billable
   but < ~£0.10/hr with teardown; anything more is `paid` and the runner
   demands `--i-am-paying`. When in doubt, round up.
6. Live-task PRs must show a `./selftest.py --live <id>` transcript run by a
   human against the pinned subscription.

## Review checklist for a live-task PR

- [ ] setup creates only in `$AZTRAIN_RG`; idempotent; tagged via `ensure_rg`
- [ ] grader read-only; asserts behaviour/end state, not command fingerprints
- [ ] solution.sh is a *reference*, not the only accepted shape
- [ ] `est_cost` truthful; SKUs are the cheapest that teach the skill
- [ ] `--live` transcript attached (setup→FAIL→solution→PASS→teardown)
