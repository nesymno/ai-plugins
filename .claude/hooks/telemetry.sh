#!/usr/bin/env bash
# SubagentStop - append one line per finished subagent for routing analysis.
# Field names in the payload are not guaranteed; the raw object is kept so
# skill-smith can recover whatever is actually there.
set -uo pipefail
IN=$(cat)
LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/telemetry/agents.jsonl"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0
printf '%s' "$IN" | jq -c --arg ts "$(date -u +%FT%TZ)" \
  '{ts:$ts, agent:(.agent_type // "unknown"), raw:.}' >> "$LOG" 2>/dev/null
exit 0
