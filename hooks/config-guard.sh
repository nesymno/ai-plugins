#!/usr/bin/env bash
# PreToolUse:Edit|Write - improver may not edit the agent security boundary.
#
# Wired at plugin scope; enforces only when .agent_type is "improver". The
# improver measures and proposes: changes to agent definitions, hooks, gates,
# or settings go to docs/agents/proposals/ as a diff plus the evidence that
# justifies them, and a human applies them.
set -uo pipefail

INPUT=$(cat)

AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
[ "$AGENT" = "improver" ] || exit 0

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
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

# The plugin's own boundary files, wherever the plugin is installed.
case "$REL" in
  */agents/*.md|agents/*.md|\
  */hooks/*|hooks/*|\
  */harness/*|harness/*|\
  */.claude-plugin/*|.claude-plugin/*)
    blocked "$REL" ;;
esac

# The host project's and user's Claude Code configuration.
case "$REL" in
  .claude/settings.json|.claude/settings.local.json|.claude/agents/*|.claude/hooks/*)
    blocked "$REL" ;;
esac
case "$FILE" in
  "$HOME"/.claude/agents/*|"$HOME"/.claude/settings*.json|"$HOME"/.claude/hooks/*)
    blocked "${FILE}" ;;
esac

exit 0
