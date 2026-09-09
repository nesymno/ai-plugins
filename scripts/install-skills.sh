#!/usr/bin/env bash
# Install the third-party skills the nesymno agents reference.
#
# Deliberately NOT installed as Claude Code plugins:
#   - skill overrides have no effect on plugin skills
#   - plugin skills are namespaced (repo:skill), which breaks the plain names
#     used in agent `skills:` fields and in hooks/skill-allowlist.sh
#
set -euo pipefail

add() { echo ">> $2 from $1"; npx --yes skills add "$1" --skill "$2"; }

# --- ripwire: the retrieval route the agents are pushed onto ---------------
# Without this binary the .mcp.json server cannot start and both
# hooks/context-discipline.sh and hooks/read-budget.sh disable themselves - the
# plugin keeps working but the agents fall back to grepping, which is the
# behaviour those gates exist to prevent.
#
# Skipped when ripwire is already on PATH, so re-running this script is cheap.
# Set NESYMNO_SKIP_RIPWIRE=1 to opt out entirely (e.g. you install it via brew).
if [ "${NESYMNO_SKIP_RIPWIRE:-0}" != "1" ] && ! command -v ripwire >/dev/null 2>&1; then
  echo ">> ripwire (binary) from redhat-et/ripwire"
  RIPWIRE_REPO=redhat-et/ripwire bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/redhat-et/ripwire/main/scripts/install.sh)"
fi

# ripwire's own agent skills, installed loose for the same reason as everything
# else here: plain names, so hooks/skill-allowlist.sh can gate them per agent.
# NOT installed with --hook: ripwire's installer would write a PreToolUse entry
# into your global ~/.claude/settings.json, and this plugin keeps every gate at
# plugin scope in hooks/hooks.json. Its advisory nudge is retired upstream
# anyway (measured inert in a randomized A/B); hooks/context-discipline.sh is
# the enforcing replacement.
if [ "${NESYMNO_SKIP_RIPWIRE:-0}" != "1" ]; then
  RW_SRC="${TMPDIR:-/tmp}/nesymno-ripwire-skills"
  rm -rf "$RW_SRC"
  git clone --depth 1 -q https://github.com/redhat-et/ripwire "$RW_SRC"
  "$RW_SRC"/skills/install.sh
fi

GO=https://github.com/samber/cc-skills-golang
GEN=https://github.com/samber/cc-skills

# --- preloaded into agents (must resolve or the agent starts without them) ---
for s in golang-safety golang-concurrency \
         golang-testing golang-stretchr-testify; do
  add "$GO" "$s"
done

# --- lazily loaded, gated by hooks/skill-allowlist.sh ---
for s in golang-error-handling golang-context golang-structs-interfaces \
         golang-design-patterns golang-data-structures golang-database \
         golang-modernize golang-how-to golang-samber-do golang-grpc \
         golang-swagger golang-observability golang-security \
         golang-performance golang-troubleshooting golang-benchmark; do
  add "$GO" "$s"
done
for s in skill-progressive-disclosure-design; do
  add "$GEN" "$s"
done

# --- fundamentals, non-Go (read these before installing: unvetted upstream) ---
AO=addyosmani/agent-skills
for s in incremental-implementation api-and-interface-design \
         code-review-and-quality code-simplification security-and-hardening \
         test-driven-development debugging-and-error-recovery; do
  add "$AO" "$s"
done
for s in systematic-debugging verification-before-completion; do
  add obra/superpowers "$s"
done

cat <<'MSG'

Done. Next:
  1. Read every SKILL.md you just installed. Bundled scripts run with your
     agent's rights.
  2. Run: harness/verify-gates.sh   (0 failures; skill warnings should be gone)
MSG
