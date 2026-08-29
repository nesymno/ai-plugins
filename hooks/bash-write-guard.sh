#!/usr/bin/env bash
# PreToolUse:Bash - keep a read-only agent read-only.
#
# Wired at plugin scope, so it fires for every Bash call. It only enforces for
# the agents that are supposed to never write (read from .agent_type). Every
# other agent and the main thread pass through untouched.
#
# These agents need Bash for go-precheck.sh, git diff, verify-gates.sh - but
# Bash also writes files (>, sed -i, tee, git commit...). This is a denylist
# and denylists leak; it enforces the "never modify" contract in the common
# cases, it is not a sandbox. Pair it with the prompt, not instead of it.
set -uo pipefail

INPUT=$(cat)

AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
case "$AGENT" in
  go-reviewer|go-qa-verifier|harness-gate) ;;
  *) exit 0 ;;
esac

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

deny() {
  printf 'BLOCKED for %s: %s\nThis agent reviews and reports - it never writes. Report the finding instead.\n' \
    "$AGENT" "$1" >&2
  exit 2
}

# 1. File redirection. Strip the safe stream redirects (/dev/null, 2>&1,
#    &>/dev/null) first; any surviving '>' writes a real file.
SANITIZED=$(printf '%s' "$CMD" |
  sed -E 's#[0-9]*>>?[[:space:]]*/dev/(null|stderr|stdout)##g; s#[0-9]*>&[0-9]##g; s#&>[[:space:]]*/dev/null##g')
printf '%s' "$SANITIZED" | grep -qE '>' && deny "file redirection (write)."

# 2. Write / mutate utilities.
printf '%s' "$CMD" | grep -qiE '\b(rm|mv|cp|dd|tee|truncate|touch|mkdir|rmdir|ln|install|chmod|chown|chgrp|shred|patch)\b' \
  && deny "filesystem-mutating command."

# 3. In-place editors.
printf '%s' "$CMD" | grep -qiE '\b(sed|perl|ruby)\b[^|]*[[:space:]]-i' && deny "in-place edit."
printf '%s' "$CMD" | grep -qiE '\b(gofmt|goimports)\b[^|]*[[:space:]]-w' && deny "in-place format write."

# 4. Go mutators. These agents run precheck / verify scripts, not raw go writes.
printf '%s' "$CMD" | grep -qiE '\bgo[[:space:]]+(generate|get|mod|work|fmt|install|build|run|clean)\b' \
  && deny "go command that writes."

# 5. Git mutators. Allow diff/log/show/status/blame/ls-files/rev-parse.
printf '%s' "$CMD" | grep -qiE '\bgit[[:space:]]+(add|commit|push|pull|fetch|reset|checkout|switch|restore|apply|am|rm|mv|stash|merge|rebase|cherry-pick|revert|tag|clean|gc|filter-branch|update-ref)\b' \
  && deny "git command that mutates the repo."

# 6. Package managers and make - can write or run arbitrary build steps.
printf '%s' "$CMD" | grep -qiE '\b(npm|yarn|pnpm|pip|pip3|cargo|apt|apt-get|brew|make)\b' \
  && deny "package manager or build tool."

# 7. Unverifiable shapes: pipe to a shell, eval, xargs into a writer.
printf '%s' "$CMD" | grep -qE '\|[[:space:]]*(sh|bash|zsh)\b|\beval\b|\bxargs\b[^|]*\b(rm|mv|cp|sed|tee|dd|truncate)\b' \
  && deny "unverifiable command shape."

exit 0
