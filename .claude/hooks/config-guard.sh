#!/usr/bin/env bash
# PreToolUse:Edit|Write - agents may not edit the agent security boundary.
set -uo pipefail

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
REL="${FILE#"$ROOT"/}"

blocked() {
  cat >&2 <<MSG
BLOCKED: $1 is part of the agent security boundary.
Write your change to docs/agents/proposals/ as a diff plus the evidence that
justifies it, and let the human apply it.
MSG
  exit 2
}

case "$REL" in
  .claude/agents/*|.claude/hooks/*|.claude/harness/*|.claude/settings.json|.claude/settings.local.json)
    blocked "$REL" ;;
esac

case "$FILE" in
  "$HOME"/.claude/agents/*|"$HOME"/.claude/settings*.json|"$HOME"/.claude/hooks/*)
    blocked "${FILE}" ;;
esac

exit 0
