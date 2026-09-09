#!/usr/bin/env bash
# PreToolUse:Grep|Bash - stop this plugin's agents from grepping a repo they
# have a call graph for.
#
# WHY A BLOCKER AND NOT A NUDGE. ripwire ships its own advisory PreToolUse hook
# that pointed agents from grep/Read toward the matching verb. Its authors
# retired the advisory path on 2026-09-02 after a randomized A/B measured both
# nudge tiers inert, and their design notes put passive skill-description
# triggering at "~30-50% reliable". An agent with grep available defaults to
# grep. So this hook denies (exit 2) and names the replacement verb, in line
# with the rest of this plugin: prompts persuade, hooks enforce.
#
# SELF-DISABLING. With no `ripwire` on PATH there is nothing to redirect to, so
# every path here exits 0. That is what keeps the plugin usable before
# scripts/install-skills.sh has been run, and what makes the .mcp.json server
# failing to start a degradation rather than a breakage.
#
# SCOPE. Enforces only for the agents that have a ripwire route. Deliberately
# NOT enforced for:
#   go-coder-fast - haiku, no Skill tool, fully-specified mechanical work; its
#                   searches are short and cheap and it has no budget to spend
#                   learning a second tool.
#   improver      - works on THIS repo's bash/markdown/JSON, where the ranked
#                   call graph buys nothing over a literal search.
#   main thread   - .agent_type is empty; never interfered with.
#
# Glob is deliberately not blocked. "Find the file named X" is cheap and often
# the honest move; blocking it buys little and breaks a lot.
#
# --assume-ripwire (TEST ONLY, used by harness/cases): skip the PATH probe and
# enforce as if the binary were present. It can only ever ENABLE enforcement -
# there is no flag that disables a gate - so it is safe to ship. Without it the
# fixtures could not assert the deny path on a machine that has no ripwire yet,
# which is every CI runner and every user before install-skills.sh.
set -uo pipefail

INPUT=$(cat)

AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
case "$AGENT" in
  go-coder|go-reviewer|go-qa-automation|go-qa-verifier|harness-gate) ;;
  *) exit 0 ;;
esac

# No binary, no redirect target, no enforcement.
ASSUME=0
for arg in "$@"; do [ "$arg" = "--assume-ripwire" ] && ASSUME=1; done
[ "$ASSUME" = "1" ] || command -v ripwire >/dev/null 2>&1 || exit 0

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

deny() {
  printf 'BLOCKED for %s: %s\n\nThis repo has a ripwire index. Use it instead:\n%s\nIf ripwire genuinely cannot answer this, say so and ask the orchestrator.\n' \
    "$AGENT" "$1" "$2" >&2
  exit 2
}

VERBS='  ripwire . --for="<what you are looking for>"   ranked symbols for a task
  ripwire . --grep='"'"'<exact literal>'"'"' --grep-context=2   an exact string
  ripwire . --callers=SYM / --uses=SYM / --impact=SYM   who touches a symbol
  ripwire . --expand=SYM                          one symbol body, not a file'

# ── The Grep tool itself.
if [ "$TOOL" = "Grep" ]; then
  deny "the Grep tool." "$VERBS"
fi

# ── grep routed through Bash. Only the recursive / repo-sweeping shapes: a
#    grep over a single named file, or over a pipeline's stdout, is a normal
#    part of running a command and is left alone.
if [ "$TOOL" = "Bash" ]; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
  [ -z "$CMD" ] && exit 0

  # A grep reading a pipe is fine - that is filtering output, not searching a repo.
  printf '%s' "$CMD" | grep -qE '\|[[:space:]]*(grep|rg|ag|ack)\b' && exit 0

  printf '%s' "$CMD" | grep -qE '(^|[;&[:space:]])(grep|egrep|fgrep)\b[^|]*[[:space:]]-[a-zA-Z]*[rR]' \
    && deny "recursive grep." "$VERBS"
  printf '%s' "$CMD" | grep -qE '(^|[;&[:space:]])(rg|ag|ack)\b' \
    && deny "a repo-wide text search (rg/ag/ack)." "$VERBS"
  printf '%s' "$CMD" | grep -qE '(^|[;&[:space:]])find\b[^|]*[[:space:]]-(name|iname|path)\b' \
    && deny "find -name over the tree." "$VERBS"
fi

exit 0
