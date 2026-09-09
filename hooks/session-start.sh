#!/usr/bin/env bash
# SessionStart - surface a broken gate before an agent relies on it.
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GATES="$ROOT/harness/verify-gates.sh"

[ -x "$GATES" ] || { echo "nesymno: $GATES missing or not executable - enforcement is unverified"; exit 0; }

out=$(CLAUDE_PROJECT_DIR="$ROOT" "$GATES" 2>&1)
if printf '%s' "$out" | grep -q 'failure(s)' && ! printf '%s' "$out" | grep -q '0 failure(s)'; then
  echo "WARNING: nesymno enforcement gates are FAILING. Run: $GATES"
  printf '%s\n' "$out" | grep -E '^(FAIL|FATAL) ' || true
fi

# ripwire is the retrieval route these agents are pushed onto. Without it the
# .mcp.json server cannot start and context-discipline / read-budget disable
# themselves - the plugin still works, but the agents fall back to grepping,
# which is the behaviour those gates exist to prevent. Say so once per session.
if ! command -v ripwire >/dev/null 2>&1; then
  echo "nesymno: 'ripwire' is not on PATH. context-discipline and read-budget are OFF and agents will fall back to grep. Install: $ROOT/scripts/install-skills.sh"
fi

exit 0
