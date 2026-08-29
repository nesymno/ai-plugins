#!/usr/bin/env bash
# Install the third-party skills the nesymno agents reference.
#
# Deliberately NOT installed as Claude Code plugins:
#   - skill overrides have no effect on plugin skills
#   - plugin skills are namespaced (repo:skill), which breaks the plain names
#     used in agent `skills:` fields and in hooks/skill-allowlist.sh
#
# platform-runbook ships inside this plugin (skills/platform-runbook) and is
# not installed here.
set -euo pipefail

add() { echo ">> $2 from $1"; npx --yes skills add "$1" --skill "$2"; }

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
         golang-performance golang-troubleshooting golang-benchmark \
         golang-lint golang-continuous-integration \
         golang-dependency-management golang-spf13-viper; do
  add "$GO" "$s"
done
for s in conventional-git skill-progressive-disclosure-design \
         promql-cli snyk-agent-scan-compliance; do
  add "$GEN" "$s"
done

# --- fundamentals, non-Go (read these before installing: unvetted upstream) ---
AO=addyosmani/agent-skills
for s in incremental-implementation api-and-interface-design \
         code-review-and-quality code-simplification security-and-hardening \
         test-driven-development debugging-and-error-recovery \
         ci-cd-and-automation observability-and-instrumentation \
         deprecation-and-migration; do
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
