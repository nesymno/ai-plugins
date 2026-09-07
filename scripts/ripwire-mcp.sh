#!/usr/bin/env bash
# stdio entrypoint for the ripwire MCP server, named by .mcp.json.
#
# A shim rather than a bare `ripwire --mcp` for one reason: when the binary is
# absent the user otherwise sees "command not found" on every session start,
# which names neither the plugin nor the fix. Failing here costs one line and
# names both. The MCP server not starting is never fatal - every agent still
# has the ripwire CLI through Bash, and hooks/context-discipline.sh disables
# itself when no binary is on PATH.
set -uo pipefail

if ! command -v ripwire >/dev/null 2>&1; then
  cat >&2 <<'MSG'
prod-ready-go-coding: 'ripwire' is not on PATH, so the ripwire MCP server cannot start.
Install it:  scripts/install-skills.sh   (or see README > Install)
Everything else in the plugin keeps working; context-discipline stays off until it is there.
MSG
  exit 1
fi

exec ripwire --mcp "$@"
