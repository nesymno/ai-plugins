#!/usr/bin/env bash
# Temporary helper. Wire this in place of any hook in hooks/hooks.json to
# capture the real payload shape, then inspect the dumped file and fix the jq
# paths in the real hook.
#
#   { "type": "command",
#     "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/_payload-debug.sh pretool-bash" }
cat > "/tmp/claude-hook-payload-${1:-unnamed}.json"
exit 0
