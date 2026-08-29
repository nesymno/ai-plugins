#!/usr/bin/env bash
# Prove that the enforcement machinery still enforces.
# Run in CI, from the SessionStart hook, and via /nesymno:verify-gates.
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"
H="hooks"
C="harness/cases"
pass=0; fail=0

fail_msg() { echo "FAIL $*"; fail=$((fail+1)); }

# 0. Interpreter dependencies. Without jq every hook silently degrades.
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq is not installed - every payload-parsing hook is a no-op."
  exit 1
fi

# 1. Executable bit. A hook without +x fails open instead of blocking.
for f in "$H"/*.sh harness/*.sh; do
  [ -e "$f" ] || continue
  [ -x "$f" ] || fail_msg "exec-bit: $f is not executable - it blocks nothing"
done

# 2. Behavioural fixtures. Each fixture pipes .input to the named hook and
#    asserts the exit code. The agent, when it matters, is .input.agent_type.
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

tmp=$(mktemp)
warn=$(mktemp)

# 3. Every skill named in an agent should resolve, or it is skipped silently at
#    runtime. A skill may be bundled here (skills/<name>), installed loose by
#    scripts/install-skills.sh (~/.claude/skills/<name>), or a plugin skill
#    referenced as <plugin>:<name> whose dir lives under a plugin cache.
#    A missing third-party skill is a WARN, not a gate failure: the user runs
#    install-skills.sh as a separate step. A skill that is neither bundled nor
#    listed in install-skills.sh is a real failure - it can never resolve.
for a in agents/*.md; do
  [ -f "$a" ] || continue
  awk '/^skills:/{f=1;next} /^[a-zA-Z_-]+:/{f=0} f&&/^ *- /{gsub(/^ *- /,"");print}' "$a" |
  while read -r s; do
    [ -z "$s" ] && continue
    base="${s##*:}"
    if [ -d "skills/$s" ] || [ -d "skills/$base" ] ||
       [ -d "$HOME/.claude/skills/$s" ] || [ -d "$HOME/.claude/skills/$base" ] ||
       [ -n "$(find "$HOME/.claude/plugins" -type d -name "$base" -path '*/skills/*' -print -quit 2>/dev/null)" ]; then
      continue
    fi
    if grep -qw "$base" scripts/install-skills.sh 2>/dev/null; then
      echo "WARN unresolved-skill: $(basename "$a") references '$s' - run scripts/install-skills.sh" >> "$warn"
    else
      echo "unknown-skill: $(basename "$a") references '$s' - not bundled and not in install-skills.sh" >> "$tmp"
    fi
  done
done

# 4. Every hook path referenced in hooks/hooks.json must exist and be executable.
grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/hooks/[A-Za-z0-9/_.-]+\.sh' hooks/hooks.json 2>/dev/null | sort -u |
while read -r ref; do
  rel="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  if [ ! -f "$rel" ]; then
    echo "dead-reference: $ref does not exist" >> "$tmp"
  elif [ ! -x "$rel" ]; then
    echo "dead-reference: $ref is not executable" >> "$tmp"
  fi
done

while IFS= read -r line; do
  [ -z "$line" ] && continue
  fail_msg "$line"
done < "$tmp"
rm -f "$tmp"

warncount=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  echo "$line"; warncount=$((warncount+1))
done < "$warn"
rm -f "$warn"

echo "gates: $pass fixture(s) passed, $fail failure(s), $warncount warning(s)"
[ "$fail" -eq 0 ]
