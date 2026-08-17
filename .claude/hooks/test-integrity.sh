#!/usr/bin/env bash
# PostToolUse:Edit|Write - block "fixing" a test by weakening it.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in *_test.go) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0

# Escape hatch: a legitimate skip must carry this marker on the same line.
#   t.Skip("no docker available") // ALLOW-SKIP: integration needs testcontainers
violations=""
add() { violations="${violations}  - $1"$'\n'; }

grep -nE '\bt\.Skip(Now)?\(' "$FILE" | grep -v 'ALLOW-SKIP' >/dev/null 2>&1 \
  && add "t.Skip without an ALLOW-SKIP justification"
grep -nE '\btesting\.Short\(\)' "$FILE" | grep -v 'ALLOW-SKIP' >/dev/null 2>&1 \
  && add "short-mode guard without an ALLOW-SKIP justification"
grep -nE 'assert\.(True|NotNil)\(t,\s*(true|1)\b' "$FILE" >/dev/null 2>&1 \
  && add "tautological assertion"
grep -nE '//\s*nolint' "$FILE" >/dev/null 2>&1 \
  && add "nolint inside a test file"

if git ls-files --error-unmatch "$FILE" >/dev/null 2>&1; then
  before=$(git show "HEAD:$FILE" 2>/dev/null | grep -cE '^func (Test|Fuzz|Benchmark)' || true)
  after=$(grep -cE '^func (Test|Fuzz|Benchmark)' "$FILE" || true)
  before=${before:-0}; after=${after:-0}
  if [ "$after" -lt "$before" ]; then
    add "test function count dropped ${before} -> ${after}"
  fi
fi

if [ -n "$violations" ]; then
  printf 'Test integrity check failed in %s:\n%s\nRemoving or weakening a test is not fixing it. Either fix the code under test, or report the failure as unresolved.\n' \
    "$FILE" "$violations" >&2
  exit 2
fi
exit 0
