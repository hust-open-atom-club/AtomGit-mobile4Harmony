#!/usr/bin/env bash
# CI gate for the local unit tests.
#
# `hvigorw test` prints BUILD SUCCESSFUL and exits 0 even when test_result.txt reports
# failures, so a green job proves nothing on its own. Run this after the test task and let it
# exit non-zero when the result file reports a failure.
#
# Usage: scripts/check-test-result.sh [path/to/test_result.txt]
set -uo pipefail

RESULT="${1:-entry/.test/default/intermediates/test/coverage_data/test_result.txt}"

if [ ! -f "$RESULT" ]; then
  echo "test gate: result file not found: $RESULT" >&2
  echo "test gate: run the unit tests first, or pass the result file path" >&2
  exit 2
fi

SUMMARY="$(grep -E '^Tests run:' "$RESULT" | tail -1)"

if [ -z "$SUMMARY" ]; then
  echo "test gate: no summary line in $RESULT, treat as failure" >&2
  exit 1
fi

FAIL="$(printf '%s\n' "$SUMMARY" | sed -n 's/.*Failure: \([0-9][0-9]*\).*/\1/p')"
ERR="$(printf '%s\n' "$SUMMARY" | sed -n 's/.*Error: \([0-9][0-9]*\).*/\1/p')"

if [ "${FAIL:-0}" -gt 0 ] || [ "${ERR:-0}" -gt 0 ]; then
  echo "test gate: $SUMMARY" >&2
  grep -B 1 'result=Failure\|result=Error' "$RESULT" >&2
  exit 1
fi

echo "test gate: $SUMMARY"
