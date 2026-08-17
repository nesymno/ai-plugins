#!/usr/bin/env bash
# SessionStart - prove the enforcement machinery is alive before work begins.
set -uo pipefail
GATES="${CLAUDE_PROJECT_DIR:-.}/.claude/harness/verify-gates.sh"
[ -x "$GATES" ] || { echo "WARNING: verify-gates.sh missing or not executable - gates are unverified."; exit 0; }
"$GATES" >/tmp/claude-gates.log 2>&1 || {
  echo "WARNING: agent enforcement gates are FAILING. Run .claude/harness/verify-gates.sh"
  tail -n 20 /tmp/claude-gates.log
}
exit 0
