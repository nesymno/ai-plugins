#!/usr/bin/env bash
# Prove that the enforcement machinery still enforces.
# Run in CI and from the SessionStart hook.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
H=.claude/hooks
C=.claude/harness/cases
pass=0; fail=0

fail_msg() { echo "FAIL $*"; fail=$((fail+1)); }

# 0. Interpreter dependencies. Without jq every hook silently degrades.
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq is not installed - every payload-parsing hook is a no-op."
  exit 1
fi

# 1. Executable bit. A hook without +x fails open instead of blocking.
for f in "$H"/*.sh .claude/harness/*.sh; do
  [ -e "$f" ] || continue
  [ -x "$f" ] || fail_msg "exec-bit: $f is not executable - it blocks nothing"
done

# 2. Behavioural fixtures.
for dir in "$C"/*/; do
  [ -d "$dir" ] || continue
  hook="$H/$(basename "$dir").sh"
  if [ ! -f "$hook" ]; then fail_msg "missing-hook: $hook"; continue; fi
  for case in "$dir"*.json; do
    [ -e "$case" ] || continue
    want=$(jq -r '.expect_exit' "$case")
    args=$(jq -r '.args // ""' "$case")
    # shellcheck disable=SC2086
    jq -c '.input' "$case" | "$hook" $args >/dev/null 2>&1
    got=$?
    if [ "$got" = "$want" ]; then
      pass=$((pass+1))
    else
      fail_msg "$case: expected exit $want, got $got"
    fi
  done
done

# 3. Every skill named in an agent must resolve, or it is silently skipped.
#    Written to a temp file because a pipeline subshell cannot update $fail.
tmp=$(mktemp)
for a in .claude/agents/*.md "$HOME"/.claude/agents/*.md; do
  [ -f "$a" ] || continue
  awk '/^skills:/{f=1;next} /^[a-zA-Z_-]+:/{f=0} f&&/^ *- /{gsub(/^ *- /,"");print}' "$a" |
  while read -r s; do
    [ -z "$s" ] && continue
    if [ ! -d ".claude/skills/$s" ] && [ ! -d "$HOME/.claude/skills/$s" ]; then
      echo "unresolved-skill: $(basename "$a") references '$s' - it will be skipped silently" >> "$tmp"
    fi
  done
done

# 4. Every hook path referenced in frontmatter or settings must exist.
grep -rhoE '\$\{CLAUDE_PROJECT_DIR\}/\.claude/[A-Za-z0-9/_.-]+\.sh' \
  .claude/agents .claude/settings.json 2>/dev/null | sort -u |
while read -r ref; do
  rel="${ref#\$\{CLAUDE_PROJECT_DIR\}/}"
  [ -f "$rel" ] || echo "dead-reference: $ref does not exist" >> "$tmp"
done

while IFS= read -r line; do
  [ -z "$line" ] && continue
  fail_msg "$line"
done < "$tmp"
rm -f "$tmp"

echo "gates: $pass fixture(s) passed, $fail failure(s)"
[ "$fail" -eq 0 ]
