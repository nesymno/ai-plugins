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

# Optional per-hook wall-clock guard: a hook that hangs would otherwise hang CI.
# timeout is GNU coreutils (timeout on Linux, gtimeout on macOS via brew); when
# neither is present we run unguarded rather than fail the suite.
TIMEOUT=""
if command -v timeout >/dev/null 2>&1; then TIMEOUT="timeout 10"
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT="gtimeout 10"; fi

# Isolated, clean git repo seeded with the fixtures. test-integrity compares a
# file against its own git HEAD (the function-count-drop check); running it here
# makes HEAD and the worktree identical, so the result no longer depends on the
# caller's branch or uncommitted edits.
SEED=$(mktemp -d)
trap 'rm -rf "$SEED"' EXIT
git init -q "$SEED" 2>/dev/null
mkdir -p "$SEED/harness"
cp -R harness/fixtures "$SEED/harness/fixtures"
git -C "$SEED" add -A 2>/dev/null
git -C "$SEED" -c user.email=gates@local -c user.name=gates commit -qm seed 2>/dev/null

# Evaluate one case. Pure: prints each failure reason on stdout, returns 0 iff
# the case passed. Kept a function so the canary below can prove the assertions
# actually fire - a silently broken evaluator would rubber-stamp everything.
eval_case() {  # $1 hook  $2 args  $3 want  $4 want_msg  $5 proj ; input on stdin
  local hook="$1" args="$2" want="$3" want_msg="$4" proj="$5" err got rc=0
  # shellcheck disable=SC2086
  err=$(CLAUDE_PROJECT_DIR="$proj" $TIMEOUT "$hook" $args 2>&1 >/dev/null); got=$?
  [ "$got" = "$want" ] || { echo "expected exit $want, got $got"; rc=1; }
  if [ -n "$want_msg" ]; then
    case "$err" in *"$want_msg"*) ;; *) echo "stderr missing '$want_msg'"; rc=1 ;; esac
  fi
  return $rc
}

# Canary: the evaluator MUST fail a deliberately-wrong expectation and pass a
# correct one. If either direction is broken, the fixture suite proves nothing.
canary=$(mktemp)
printf '#!/usr/bin/env bash\necho boom >&2\nexit 1\n' > "$canary"; chmod +x "$canary"
if echo '{}' | eval_case "$canary" "" "0" "absent-substring" "$ROOT" >/dev/null; then
  fail_msg "canary: evaluator passed a case it should have failed - assertions are dead"
fi
if ! echo '{}' | eval_case "$canary" "" "1" "boom" "$ROOT" >/dev/null; then
  fail_msg "canary: evaluator failed a case it should have passed"
fi
rm -f "$canary"

# 2. Behavioural fixtures. Each fixture pipes .input to the named hook and
#    asserts the exit code (and, when given, expect_stderr). The agent, when it
#    matters, is .input.agent_type.
for dir in "$C"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  hook="$H/$name.sh"
  if [ ! -f "$hook" ]; then fail_msg "missing-hook: $hook"; continue; fi
  # test-integrity reads git history, so run its cases against the seeded clean
  # repo; every other hook runs against the real project root.
  proj="$ROOT"; [ "$name" = "test-integrity" ] && proj="$SEED"
  for case in "$dir"*.json; do
    [ -e "$case" ] || continue
    want=$(jq -r '.expect_exit' "$case")
    want_msg=$(jq -r '.expect_stderr // ""' "$case")
    args=$(jq -r '.args // ""' "$case")
    if reasons=$(jq -c '.input' "$case" | eval_case "$hook" "$args" "$want" "$want_msg" "$proj"); then
      pass=$((pass+1))
    else
      while IFS= read -r r; do [ -n "$r" ] && fail_msg "$case: $r"; done <<< "$reasons"
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
#    The command strings are "${CLAUDE_PLUGIN_ROOT}"/hooks/x.sh - note the quote
#    between } and / - so parse the JSON with jq rather than regex-matching the
#    raw text, and derive the repo-relative path from the /hooks/ segment.
jq -r '.hooks[]?[]?.hooks[]?.command // empty' hooks/hooks.json 2>/dev/null |
grep '/hooks/' | sort -u |
while read -r ref; do
  rel="hooks/${ref##*/hooks/}"
  if [ ! -f "$rel" ]; then
    echo "dead-reference: $ref does not exist" >> "$tmp"
  elif [ ! -x "$rel" ]; then
    echo "dead-reference: $ref is not executable" >> "$tmp"
  fi
done

# 5. Every gate script must actually run somewhere, or it silently protects
#    nothing. An event hook is wired in hooks/hooks.json; a standalone gate
#    (e.g. go-precheck.sh) is invoked by an agent or command. A script that is
#    neither is orphaned. Helper scripts (leading _) are exempt.
registered=$(jq -r '.hooks[]?[]?.hooks[]?.command // empty' hooks/hooks.json 2>/dev/null)
for f in "$H"/*.sh; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  case "$b" in _*) continue ;; esac
  case "$registered" in *"/hooks/$b"*) continue ;; esac
  grep -rq "$b" agents commands 2>/dev/null && continue
  echo "unwired-hook: $b is neither wired in hooks/hooks.json nor invoked by any agent/command - it never runs" >> "$tmp"
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
