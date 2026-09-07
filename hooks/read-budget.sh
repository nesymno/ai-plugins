#!/usr/bin/env bash
# PreToolUse:Read - cap WHOLE-FILE reads per agent per session.
#
# The whole-file Read is the largest token sink in an agent loop and the one
# default no skill description intercepts: loading a skill costs a tool call and
# requires the agent to first recognize the moment; `Read` needs neither. So
# this is a budget, not advice - the same reasoning that makes
# context-discipline a blocker rather than a nudge.
#
# WHAT COUNTS. Only a Read with NO offset/limit. A ranged read is already the
# disciplined form and is never counted or blocked, so the escape hatch from
# this hook is the behaviour the hook is trying to produce.
#
# BUDGET. Default 15 per agent per session, overridable by NESYMNO_READ_BUDGET
# or by passing --budget=N (the harness fixtures use the flag). Start generous
# and tighten against hooks/telemetry.sh: an agent that never reaches the cap
# costs nothing, and a cap that fires constantly is a prompt problem, not a
# budget problem.
#
# SELF-DISABLING, same contract as context-discipline: without a `ripwire`
# binary there is no cheaper alternative to point at, so exit 0 everywhere.
#
# --assume-ripwire (TEST ONLY, used by harness/cases): skip the PATH probe and
# enforce as if the binary were present. It can only ever ENABLE enforcement -
# there is no flag that disables a gate - so it is safe to ship. Without it the
# fixtures could not assert the deny path on a machine that has no ripwire yet,
# which is every CI runner and every user before install-skills.sh.
set -uo pipefail

BUDGET="${NESYMNO_READ_BUDGET:-15}"
for arg in "$@"; do
  case "$arg" in --budget=*) BUDGET="${arg#--budget=}" ;; esac
done

INPUT=$(cat)

AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
case "$AGENT" in
  go-coder|go-reviewer|go-qa-automation|go-qa-verifier|harness-gate) ;;
  *) exit 0 ;;
esac

ASSUME=0
for arg in "$@"; do [ "$arg" = "--assume-ripwire" ] && ASSUME=1; done
[ "$ASSUME" = "1" ] || command -v ripwire >/dev/null 2>&1 || exit 0

# A ranged read is the disciplined form. Never counted, never blocked.
#    NOTE: `x != empty` is not a null test - `empty` yields no output, so the
#    whole expression produces nothing and the guard silently never fires.
#    Compare against null.
RANGED=$(printf '%s' "$INPUT" | jq -r '
  if (.tool_input.offset != null) or (.tool_input.limit != null)
  then "1" else "0" end' 2>/dev/null)
[ "$RANGED" = "1" ] && exit 0

SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION" ] && SESSION="ppid-$PPID"

# One counter per (session, agent). Subagents of the same type in one session
# share a budget deliberately: the budget is the session's context, not one
# dispatch's.
DIR="${TMPDIR:-/tmp}/nesymno-read-budget"
mkdir -p "$DIR" 2>/dev/null || exit 0
SAFE=$(printf '%s-%s' "$SESSION" "$AGENT" | tr -c 'A-Za-z0-9._-' '_')
COUNTER="$DIR/$SAFE"

n=0
[ -f "$COUNTER" ] && n=$(cat "$COUNTER" 2>/dev/null)
case "$n" in ''|*[!0-9]*) n=0 ;; esac

if [ "$n" -ge "$BUDGET" ]; then
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // "that file"' 2>/dev/null)
  cat >&2 <<MSG
BLOCKED for $AGENT: whole-file read budget spent ($n/$BUDGET this session).

Cheaper ways to get what you want from $FILE:
  ripwire . --expand=SYM          the one symbol's body
  ripwire . --for="<question>"    ranked symbols with signatures
  Read with offset/limit          a range - never counted against this budget

If you truly need the whole file, read it in ranges and say why.
MSG
  exit 2
fi

printf '%s' "$((n + 1))" > "$COUNTER" 2>/dev/null
exit 0
