#!/usr/bin/env python3
"""
selftest.py — prove every task and grader in this repo actually works.

For each LOCAL task it runs, in a throwaway workspace:
    grade.sh on the starter (expect FAIL)  ->  grade.sh on the solution (expect PASS)
That catches BOTH failure modes:
    * a grader that passes before you've done anything (too lax / pre-satisfied)
    * a grader that fails on a correct solution (too strict / wrong)

It also validates repo structure (every task dir MUST have meta.json — a
meta-less dir is an error, not a skip) and counts task coverage per domain
against the official objectives in docs/objectives.md.

Cloud tasks are structurally validated here but only exercised with --live:
    ./selftest.py --live          # runs whatif+live tasks against the PINNED sub:
                                  # setup -> grade(FAIL) -> solution.sh -> grade(PASS)
                                  # teardown is guaranteed, even on failure.
--live is for you, at your desk, on the training subscription; CI never runs it.

Usage:
    ./selftest.py [-j N] [--verbose] [task-id ...]
    ./selftest.py --live [task-id ...]
"""
import importlib.machinery
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parent
TASKS = REPO / "tasks"

# The runner is the single source of truth for env vars, RG names, pin logic.
_loader = importlib.machinery.SourceFileLoader("aztrain_runner", str(REPO / "aztrain"))
_spec = importlib.util.spec_from_loader("aztrain_runner", _loader)
runner = importlib.util.module_from_spec(_spec)
_loader.exec_module(runner)

GRN = runner.GRN
RED = runner.RED
YEL = runner.YEL
DIM = runner.DIM
BLD = runner.BLD

REQUIRED_META = ("title", "objective", "est_min", "difficulty", "kind", "est_cost")

def fail(errors, msg):
    errors.append(msg)
    print(RED(f"  ✗ {msg}"))

# ---- structure --------------------------------------------------------------
def check_structure():
    """Every leaf dir under tasks/ must be a well-formed task. Returns
    (tasks, errors) where tasks is {tid: meta}."""
    errors = []
    print(BLD("\n== structure =="))
    task_dirs = sorted(d for d in TASKS.rglob("*") if d.is_dir() and (d / "meta.json").exists())
    def inside_task(d):
        return any((p / "meta.json").exists() for p in d.parents if TASKS in p.parents or p == TASKS)
    for d in sorted(TASKS.rglob("*")):
        # a dir that is neither a task, nor a parent of tasks, nor task content
        # (starter/solution trees) is a meta-less task dir — an error, not a skip
        if (d.is_dir() and not d.name.startswith(".") and d not in task_dirs
                and not any(t != d and d in t.parents for t in task_dirs)
                and not inside_task(d)):
            fail(errors, f"{d.relative_to(REPO)}: directory without meta.json (every task needs one)")

    tasks = {}
    leaves = {}
    for d in task_dirs:
        tid = d.relative_to(TASKS).as_posix()
        try:
            meta = json.loads((d / "meta.json").read_text())
        except json.JSONDecodeError as e:
            fail(errors, f"{tid}: unparseable meta.json ({e})")
            continue
        for f in REQUIRED_META:
            if f not in meta:
                fail(errors, f"{tid}: meta.json missing '{f}'")
        kind = meta.get("kind")
        if kind not in runner.KINDS:
            fail(errors, f"{tid}: kind '{kind}' not one of {runner.KINDS}")
        if meta.get("est_cost") not in runner.COSTS:
            fail(errors, f"{tid}: est_cost '{meta.get('est_cost')}' not one of {runner.COSTS}")
        if kind == "local" and meta.get("est_cost") != "free":
            fail(errors, f"{tid}: local tasks must be est_cost 'free'")
        if not (d / "prompt.md").exists():
            fail(errors, f"{tid}: missing prompt.md")
        if not (d / "grade.sh").exists():
            fail(errors, f"{tid}: missing grade.sh")
        if not (d / "solution").is_dir() and not (d / "solution.sh").exists():
            fail(errors, f"{tid}: needs solution/ or solution.sh")
        if kind in ("whatif", "live") and not meta.get("bootstrap"):
            for req in ("setup.sh", "solution.sh"):
                if not (d / req).exists():
                    fail(errors, f"{tid}: {kind} task missing {req}")
        # graders must never destroy: cheap lint for the worst offenders
        gtext = (d / "grade.sh").read_text() if (d / "grade.sh").exists() else ""
        if re.search(r"\baz\s+(group\s+delete|\S+\s+delete)", gtext):
            fail(errors, f"{tid}: grade.sh contains an az delete — graders only READ state")
        leaf = d.name
        if leaf in leaves:
            fail(errors, f"{tid}: leaf name '{leaf}' collides with {leaves[leaf]} "
                         f"(ids and rg-aztrain-* names must be unique)")
        leaves[leaf] = tid
        meta["_dir"] = d
        tasks[tid] = meta
    if not errors:
        print(GRN(f"  ✓ {len(tasks)} task dirs well-formed"))
    return tasks, errors

# ---- coverage ---------------------------------------------------------------
def check_coverage(tasks):
    """Count tasks per domain-dir against docs/objectives.md."""
    errors = []
    print(BLD("\n== coverage vs docs/objectives.md =="))
    text = (REPO / "docs/objectives.md").read_text()
    sections = []  # (header, domain_dir, n_bullets)
    for m in re.finditer(
            r"^### (.+?)$\s+<!-- domain-dir: (\S+) -->(.*?)(?=^###?|\Z)",
            text, re.M | re.S):
        header, ddir, body = m.group(1), m.group(2), m.group(3)
        bullets = len(re.findall(r"^- \[[ x]\]", body, re.M))
        sections.append((header.strip(), ddir, bullets))
    if not sections:
        errors.append("docs/objectives.md has no parseable '### slug — name' + domain-dir sections")
        return errors
    known_dirs = {s[1] for s in sections} | {"tasks/setup"}
    per_domain = {}
    for tid, meta in tasks.items():
        ddir = "tasks/" + "/".join(tid.split("/")[:-1])
        per_domain[ddir] = per_domain.get(ddir, 0) + 1
        if ddir not in known_dirs:
            fail(errors, f"{tid}: domain dir {ddir} is not declared in docs/objectives.md")
    for header, ddir, bullets in sections:
        n = per_domain.get(ddir, 0)
        mark = GRN("✓") if n else DIM("·")
        print(f"  {mark} {ddir:<38} {n:>3} tasks / {bullets:>3} outline skills")
    setup_n = per_domain.get("tasks/setup", 0)
    print(f"  {GRN('✓') if setup_n else DIM('·')} {'tasks/setup':<38} {setup_n:>3} tasks")
    return errors

# ---- fail-before / pass-after -----------------------------------------------
def run_grader(meta, tid, ws, timeout=300):
    env = runner.grader_env(tid, meta)
    env["AZTRAIN_WS"] = str(ws)
    p = subprocess.run(["bash", str(meta["_dir"] / "grade.sh")],
                       capture_output=True, text=True, env=env, cwd=str(ws),
                       stdin=subprocess.DEVNULL, timeout=timeout)
    return p.returncode == 0, p.stdout + p.stderr

def selftest_local(tid, meta, verbose=False):
    """Returns (tid, ok, detail)."""
    d = meta["_dir"]
    with tempfile.TemporaryDirectory(prefix="aztrain-selftest-") as tmp:
        ws = Path(tmp) / "ws"
        ws.mkdir()
        if (d / "starter").is_dir():
            shutil.copytree(d / "starter", ws, dirs_exist_ok=True)
        neg_pass, neg_out = run_grader(meta, tid, ws)
        if neg_pass:
            return tid, False, "grader PASSES on the starter (too lax)" + \
                (f"\n{neg_out}" if verbose else "")
        # apply the solution: file tree preferred, else scripted
        if (d / "solution").is_dir():
            shutil.copytree(d / "solution", ws, dirs_exist_ok=True)
        else:
            p = subprocess.run(["bash", str(d / "solution.sh")], capture_output=True,
                               text=True, cwd=str(ws), stdin=subprocess.DEVNULL,
                               env={**runner.grader_env(tid, meta), "AZTRAIN_WS": str(ws)},
                               timeout=300)
            if p.returncode != 0:
                return tid, False, f"solution.sh failed:\n{p.stdout}{p.stderr}"
        pos_pass, pos_out = run_grader(meta, tid, ws)
        if not pos_pass:
            return tid, False, "grader FAILS on the reference solution (too strict/wrong)" + \
                (f"\n{pos_out}" if verbose else "")
    return tid, True, ""

# ---- live -------------------------------------------------------------------
def selftest_live(tid, meta, verbose=False):
    """setup -> grade(FAIL) -> solution.sh -> grade(PASS), teardown GUARANTEED."""
    ws = runner.ws_dir(tid)
    ws.mkdir(parents=True, exist_ok=True)
    rg = runner.rg_for(tid)
    try:
        rc, out = runner.run_task_script(tid, meta, "setup.sh", timeout=900)
        if rc not in (0, None):
            return tid, False, f"setup.sh failed:\n{out}"
        neg_pass, neg_out = run_grader(meta, tid, ws, timeout=600)
        if neg_pass:
            return tid, False, "grader PASSES right after setup (too lax)"
        rc, out = runner.run_task_script(tid, meta, "solution.sh", timeout=900)
        if rc not in (0, None):
            return tid, False, f"solution.sh failed:\n{out}"
        pos_pass, pos_out = run_grader(meta, tid, ws, timeout=600)
        if not pos_pass:
            return tid, False, "grader FAILS after the reference solution" + \
                (f"\n{pos_out}" if verbose else "")
        return tid, True, ""
    finally:
        subprocess.run(["az", "group", "delete", "-n", rg, "--yes", "--no-wait"],
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
        runner.invalidate_rg_cache()

# ---- main ---------------------------------------------------------------------
def main():
    args = sys.argv[1:]
    live = "--live" in args
    verbose = "--verbose" in args or "-v" in args
    jobs = 4
    if "-j" in args:
        i = args.index("-j")
        jobs = int(args[i + 1])
        del args[i:i + 2]
    wanted = [a for a in args if not a.startswith("-")]

    tasks, errors = check_structure()
    errors += check_coverage(tasks)

    if wanted:
        ids = [runner.resolve(tasks, w) for w in wanted]
        tasks = {t: tasks[t] for t in ids}

    if not live:
        local = {t: m for t, m in tasks.items() if m.get("kind") == "local"}
        cloud = [t for t, m in tasks.items() if m.get("kind") != "local"]
        print(BLD(f"\n== fail-before/pass-after: {len(local)} local tasks "
                  f"(-j {jobs}) =="))
        if cloud:
            print(DIM(f"  ({len(cloud)} whatif/live tasks structurally checked only — "
                      f"run ./selftest.py --live yourself to exercise them)"))
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            results = list(ex.map(lambda kv: selftest_local(kv[0], kv[1], verbose),
                                  sorted(local.items())))
    else:
        pin = runner.pinned_sub()
        active = runner.active_sub()
        if not pin or not active or active.lower() != pin.lower():
            print(RED("--live needs the pinned training subscription active "
                      "(complete setup/00, then az account set -s <pin>)"))
            sys.exit(1)
        cloud = {t: m for t, m in sorted(tasks.items())
                 if m.get("kind") in ("whatif", "live") and not m.get("bootstrap")}
        print(BLD(f"\n== LIVE fail-before/pass-after: {len(cloud)} tasks on "
                  f"subscription {pin[:8]}… (serial; teardown guaranteed) =="))
        results = [selftest_live(t, m, verbose) for t, m in cloud.items()]

    ok = 0
    for tid, passed, detail in results:
        if passed:
            print(f"  {GRN('✓')} {tid}")
            ok += 1
        else:
            print(f"  {RED('✗')} {tid} — {detail}")
            errors.append(f"{tid}: {detail.splitlines()[0]}")
    print(BLD(f"\nverified: {ok}/{len(results)}   structural/coverage errors: "
              f"{len(errors) - (len(results) - ok)}"))
    if errors:
        print(RED(f"\nselftest FAILED ({len(errors)} problem(s))"))
        sys.exit(1)
    print(GRN("\nselftest PASSED"))

if __name__ == "__main__":
    main()
