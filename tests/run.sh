#!/usr/bin/env bash
# Runner de tests para common.sh. Corre en macOS (bash 3.2) y Ubuntu.
set -u
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"
export PATH="$TESTS_DIR/mock:$PATH"
export MOCK_AWS_CONFIG="$TESTS_DIR/fixtures/aws_config"

PASS=0; FAIL=0

assert_eq() { # <actual> <expected> <msg>
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); printf '  ok: %s\n' "$3"
  else FAIL=$((FAIL+1)); printf '  FAIL: %s (got [%s] want [%s])\n' "$3" "$1" "$2"; fi
}
assert_ok() { # <rc> <msg>
  if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok: %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL: %s (rc=%s)\n' "$2" "$1"; fi
}
assert_fail() { # <rc> <msg>
  if [ "$1" -ne 0 ]; then PASS=$((PASS+1)); printf '  ok: %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL: %s (rc=0)\n' "$2"; fi
}

# shellcheck source=/dev/null
. "$REPO_DIR/common.sh"

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  printf '%s\n' "$t"
  "$t"
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
