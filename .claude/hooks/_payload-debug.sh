#!/usr/bin/env bash
# Temporary helper. Wire this in place of any hook to capture the real
# payload shape, then inspect /tmp/claude-hook-payload.json and fix the
# jq paths in the real hook.
#
#   command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/_payload-debug.sh PreToolUse-Bash"
cat > "/tmp/claude-hook-payload-${1:-unnamed}.json"
exit 0
