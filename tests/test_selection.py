#!/usr/bin/env python3
"""
Lightweight unit tests for the train/learn selection + spaced-repetition logic
in the aztrain runner. Stdlib only (no pytest), so it runs anywhere the trainer
does. Uses synthetic task/state dicts — it never touches real progress, the real
task tree, or Azure.

    ./tests/test_selection.py    # prints a line per check, exits nonzero on failure
"""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile
from datetime import date, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Load the runner as a module. Point state/config at a throwaway dir FIRST, so
# importing/exercising it can never read or write real user progress.
_tmp = tempfile.mkdtemp(prefix="aztrain-tests-")
os.environ["XDG_STATE_HOME"] = str(Path(_tmp) / "state")
os.environ["XDG_CONFIG_HOME"] = str(Path(_tmp) / "config")

_loader = importlib.machinery.SourceFileLoader("aztrain_runner", str(REPO / "aztrain"))
_spec = importlib.util.spec_from_loader("aztrain_runner", _loader)
r = importlib.util.module_from_spec(_spec)
_loader.exec_module(r)

_fails = []
def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        _fails.append(name)

def iso(days_from_today):
    return (date.today() + timedelta(days=days_from_today)).isoformat()

def local(**over):
    m = {"title": "t", "kind": "local", "est_cost": "free"}
    m.update(over)
    return m

# Synthetic task set spanning three AZ-104 domains in a known teaching order,
# plus a cloud task and the bootstrap, to exercise cloud gating.
TASKS = {
    "az104/storage/01-a":     local(title="a"),
    "az104/storage/02-b":     local(title="b"),
    "az104/compute/01-c":     local(title="c"),
    "az104/networking/01-d":  local(title="d"),
    "setup/00-boot":          {"title": "boot", "kind": "live", "est_cost": "free", "bootstrap": True},
    "az104/networking/09-live": {"title": "live", "kind": "live", "est_cost": "pennies"},
    "az104/compute/09-paid":  {"title": "paid", "kind": "live", "est_cost": "paid"},
}

def blank_state(**over):
    st = {"tasks": {}, "xp": 0, "streak": {"count": 0, "last": ""},
          "current": None, "recent_picks": []}
    st.update(over)
    return st

# ---- spaced-repetition ladder ---------------------------------------------
check("review_interval ladder is 1,3,7,16,35,75",
      [r.review_interval(n) for n in range(1, 7)] == [1, 3, 7, 16, 35, 75])
check("review_interval doubles past the ladder",
      r.review_interval(7) == 150 and r.review_interval(8) == 300)
check("days_overdue: None when unscheduled", r.days_overdue("") is None)
check("days_overdue: 0 when due today", r.days_overdue(iso(0)) == 0)
check("days_overdue: positive when past due", r.days_overdue(iso(-3)) == 3)
check("days_overdue: negative when in the future", r.days_overdue(iso(5)) == -5)

entry = {}
r.schedule_review(entry, 2)
check("schedule_review records reps + a due 3d out (reps=2)",
      entry["reps"] == 2 and entry["due"] == iso(3))

# ---- teaching order --------------------------------------------------------
check("curriculum_key orders storage < compute < networking, setup first",
      sorted(["az104/compute/01-c", "az104/storage/01-a",
              "az104/networking/01-d", "setup/00-boot"], key=r.curriculum_key)
      == ["setup/00-boot", "az104/storage/01-a",
          "az104/compute/01-c", "az104/networking/01-d"])

# ---- selectable: local always, cloud gated, bootstrap always, paid never ---
check("selectable: local task regardless of cloud readiness",
      r.selectable(local(), False) and r.selectable(local(), True))
check("selectable: cloud task only when the subscription is ready",
      not r.selectable(TASKS["az104/networking/09-live"], False)
      and r.selectable(TASKS["az104/networking/09-live"], True))
check("selectable: bootstrap always (the on-ramp), even when not ready",
      r.selectable(TASKS["setup/00-boot"], False))
check("selectable: paid never auto-selected, even when ready",
      not r.selectable(TASKS["az104/compute/09-paid"], True))

# ---- next_new: fundamentals first, cloud gating, resumes unfinished --------
st = blank_state()
check("next_new on a clean slate surfaces the bootstrap first",
      r.next_new(TASKS, st, False)[0] == "setup/00-boot")
st = blank_state(tasks={"setup/00-boot": {"passed": True}})
check("next_new after setup, not cloud-ready, is the first local task",
      r.next_new(TASKS, st, False)[0] == "az104/storage/01-a")
st = blank_state(tasks={"setup/00-boot": {"passed": True}, "az104/storage/01-a": {"passed": True}})
check("next_new skips a passed task",
      r.next_new(TASKS, st, False)[0] == "az104/storage/02-b")
st = blank_state(tasks={"az104/storage/01-a": {"passed": False, "attempts": 2},
                        "setup/00-boot": {"passed": True}})
check("next_new returns an attempted-but-unpassed task (resume)",
      r.next_new(TASKS, st, False)[0] == "az104/storage/01-a")
# a cloud task only enters the sequence once ready
st = blank_state(tasks={t: {"passed": True} for t in TASKS
                        if TASKS[t]["kind"] == "local" or TASKS[t].get("bootstrap")})
check("next_new skips a not-ready cloud task (stays None if only cloud left)",
      r.next_new(TASKS, st, False) is None)
check("next_new surfaces the cloud task once ready (paid still excluded)",
      r.next_new(TASKS, st, True)[0] == "az104/networking/09-live")

# ---- due_reviews -----------------------------------------------------------
st = blank_state(tasks={
    "az104/storage/01-a":    {"passed": True, "due": iso(-5)},   # 5d overdue
    "az104/storage/02-b":    {"passed": True, "due": iso(-1)},   # 1d overdue
    "az104/compute/01-c":    {"passed": True, "due": iso(10)},   # not yet due
    "az104/networking/01-d": {"passed": True},                   # passed, unscheduled
    "setup/00-boot":         {"passed": True, "due": iso(-9)},   # bootstrap: never reviewed
})
due = [tid for tid, _ in r.due_reviews(TASKS, st, True)]
check("due_reviews excludes not-yet-due tasks", "az104/compute/01-c" not in due)
check("due_reviews includes an unscheduled passed task", "az104/networking/01-d" in due)
check("due_reviews never reviews a bootstrap task", "setup/00-boot" not in due)
check("due_reviews is most-overdue-first",
      due[0] == "az104/storage/01-a" and due[1] == "az104/storage/02-b")

# ---- choose_task: reviews vs new, and the two-in-a-row wall ----------------
st = blank_state(tasks={"az104/storage/01-a": {"passed": True, "due": iso(-2)},
                        "setup/00-boot": {"passed": True}})
tid, meta, kind, reason = r.choose_task(TASKS, st, True)
check("choose_task prefers a due review", kind == "review" and tid == "az104/storage/01-a")

st = blank_state()
tid, meta, kind, reason = r.choose_task(TASKS, st, False)
check("choose_task gives new material when nothing is due",
      kind == "new" and tid == "setup/00-boot")

# two reviews in a row + new material waiting -> the 3rd pick must be new
st = blank_state(
    tasks={"az104/storage/01-a": {"passed": True, "due": iso(-2)}},
    recent_picks=["review", "review"],
)
tid, meta, kind, reason = r.choose_task(TASKS, st, False)
check("choose_task never gives 3 reviews in a row while new work waits",
      kind == "new")

# but if there is NO new material left, a review is fine even after two
st = blank_state(
    tasks={t: {"passed": True, "due": iso(-2)} for t in TASKS
           if TASKS[t]["kind"] == "local" or TASKS[t].get("bootstrap")},
    recent_picks=["review", "review"],
)
tid, meta, kind, reason = r.choose_task(TASKS, st, False)
check("choose_task falls back to review when all new material is done",
      kind == "review")

# nothing due, nothing new
st = blank_state(tasks={t: {"passed": True, "due": iso(30)} for t in TASKS
                        if TASKS[t]["kind"] == "local" or TASKS[t].get("bootstrap")})
tid, meta, kind, reason = r.choose_task(TASKS, st, False)
check("choose_task returns None when caught up", tid is None and kind is None)

# ---- lesson parsing --------------------------------------------------------
beats = r.parse_lesson("intro\n---\nmore\n```run\necho hi\necho bye\n```\ntail")
kinds = [b[0] for b in beats]
check("parse_lesson splits prose / pause / run / prose",
      kinds == ["prose", "pause", "prose", "run", "prose"])
check("parse_lesson keeps a run block verbatim, tagged with its fence",
      beats[3][1] == ("run", ["echo hi", "echo bye"]))

# ---- Azure-safety classifier (the key divergence) --------------------------
check("block_is_cloud: local read-only bicep build is SAFE (auto-runnable)",
      not r.block_is_cloud(['az bicep build --file main.bicep --stdout']))
check("block_is_cloud: az --version is SAFE",
      not r.block_is_cloud(['az --version']))
check("block_is_cloud: plain shell (echo/cat/python) is SAFE",
      not r.block_is_cloud(['cat > f.bicep <<EOF', 'echo x', 'python3 tools/x.py']))
check("block_is_cloud: az login is CLOUD (present-only)",
      r.block_is_cloud(['az login --use-device-code']))
check("block_is_cloud: az group create (mutating) is CLOUD",
      r.block_is_cloud(['az group create -n rg -l uksouth']))
check("block_is_cloud: az account show (authenticates) is CLOUD",
      r.block_is_cloud(['az account show --query id -o tsv']))
check("block_is_cloud: az bicep install (writes tooling) is CLOUD/present-only",
      r.block_is_cloud(['az bicep install']))
check("block_is_cloud: a safe line then a mutating az is CLOUD (whole block)",
      r.block_is_cloud(['az bicep build --file m.bicep', 'az deployment group create -g rg -f m.bicep']))
check("block_is_cloud: 'azure'/'az104' tokens do NOT false-trigger",
      not r.block_is_cloud(['echo azure az104 azret']))

print("----")
if _fails:
    print(f"FAILED {len(_fails)}: " + ", ".join(_fails))
    sys.exit(1)
print("all selection/SR/safety checks passed")
