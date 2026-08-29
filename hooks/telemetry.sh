#!/usr/bin/env bash
# SubagentStop - append one line per finished subagent for routing analysis.
# Field names in the payload are not guaranteed; the raw object is kept so the
# improver can recover whatever is actually there.
#
# Written under CLAUDE_PLUGIN_DATA (persists across plugin updates, stays out of
# the host project). Falls back to the plugin dir if that is unset.
set -uo pipefail
IN=$(cat)

BASE="${CLAUDE_PLUGIN_DATA:-${CLAUDE_PLUGIN_ROOT:-.}}"
LOG="$BASE/telemetry/agents.jsonl"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0

printf '%s' "$IN" | jq -c --arg ts "$(date -u +%FT%TZ)" \
  '{ts:$ts, agent:(.agent_type // "unknown"), raw:.}' >> "$LOG" 2>/dev/null
exit 0
