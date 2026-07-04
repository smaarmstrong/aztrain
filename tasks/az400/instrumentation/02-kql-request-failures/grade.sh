#!/usr/bin/env bash
# Run the learner's KQL through the fixture engine; compare rows (any order).
. "$AZTRAIN_REPO/lib/common.sh"

OUT=$(python3 "$AZTRAIN_REPO/tools/kqlgrade.py" \
        "$AZTRAIN_TASK_DIR/fixture.json" \
        "$AZTRAIN_WS/query.kql" \
        "$AZTRAIN_TASK_DIR/expected.json" 2>&1)
RC=$?
echo "$OUT" | sed 's/^/  /'
[ $RC -eq 0 ] && _PASS=$((_PASS + 1)) || _FAIL=$((_FAIL + 1))

grade_summary
