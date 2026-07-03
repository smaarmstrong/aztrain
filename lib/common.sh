#!/usr/bin/env bash
# common.sh — shared helpers for aztrain task scripts (setup/grade/solution).
#
# Graders source this (via the header below) and then call:
#   check      "description"  cmd args...      # pass if cmd exits 0
#   check_eval "description" 'shell string'    # pass if the string evals 0 (pipes/globs ok)
#   check_az   "description" "expected" query args...
#                                              # pass if `az query args... -o tsv` == expected
#   grade_summary                              # prints PASS/FAIL, sets exit status
#
# Source header for task scripts (works from any depth under tasks/):
#   . "$AZTRAIN_REPO/lib/common.sh"
#
# RULES FOR GRADERS (enforced in review + selftest):
#   * grade.sh only READS state: az ... show/list/--query. Never create/delete.
#   * setup.sh creates only inside "$AZTRAIN_RG" (plus the RG itself, tagged).
#   * teardown is the runner's job — task scripts never delete resource groups.

# ----- colours (disabled when not a terminal) --------------------------------
if [ -t 1 ]; then
  C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_B=$'\033[34m'
  C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
  C_G=; C_R=; C_Y=; C_B=; C_BOLD=; C_DIM=; C_0=
fi

# ----- grading ---------------------------------------------------------------
_PASS=0; _FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf "  ${C_G}✓${C_0} %s\n" "$desc"; _PASS=$((_PASS + 1))
  else
    printf "  ${C_R}✗${C_0} %s\n" "$desc"; _FAIL=$((_FAIL + 1))
  fi
}

check_eval() {
  local desc="$1" expr="$2"
  if eval "$expr" >/dev/null 2>&1; then
    printf "  ${C_G}✓${C_0} %s\n" "$desc"; _PASS=$((_PASS + 1))
  else
    printf "  ${C_R}✗${C_0} %s\n" "$desc"; _FAIL=$((_FAIL + 1))
  fi
}

# check_az "desc" "expected" account show --query user.type
check_az() {
  local desc="$1" want="$2"; shift 2
  local got
  got=$(az "$@" -o tsv 2>/dev/null)
  if [ "$got" = "$want" ]; then
    printf "  ${C_G}✓${C_0} %s\n" "$desc"; _PASS=$((_PASS + 1))
  else
    printf "  ${C_R}✗${C_0} %s ${C_DIM}(got: %s)${C_0}\n" "$desc" "${got:-<nothing>}"; _FAIL=$((_FAIL + 1))
  fi
}

grade_summary() {
  local total=$((_PASS + _FAIL))
  echo
  if [ "$_FAIL" -eq 0 ] && [ "$total" -gt 0 ]; then
    printf "${C_G}${C_BOLD}PASS${C_0} — %d/%d checks passed\n" "$_PASS" "$total"
    return 0
  fi
  printf "${C_R}${C_BOLD}FAIL${C_0} — %d/%d checks passed\n" "$_PASS" "$total"
  return 1
}

# ----- setup helpers ----------------------------------------------------------
# Create (idempotently) this task's resource group, tagged so it is auditable.
ensure_rg() {
  az group create -n "$AZTRAIN_RG" -l "$AZTRAIN_LOCATION" \
    --tags aztrain=1 "aztrain-task=$AZTRAIN_TASK_ID" -o none
}

# Compile the learner's Bicep to ARM JSON on stdout; fails loudly if bicep is
# missing. Usage: bicep_build "$AZTRAIN_WS/main.bicep" > /tmp/compiled.json
bicep_build() {
  if ! az bicep version >/dev/null 2>&1; then
    printf "${C_Y}bicep is not installed — run: az bicep install${C_0}\n" >&2
    return 1
  fi
  az bicep build --file "$1" --stdout 2>/dev/null
}
