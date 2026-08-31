#!/usr/bin/env bash
# PreToolUse:Skill - restrict which skills an agent may load lazily.
#
# Wired at plugin scope in hooks/hooks.json, so it fires for every Skill call
# in the session. The agent is read from .agent_type in the payload. Any agent
# not listed below - including the main thread, where .agent_type is empty - is
# left unrestricted.
#
# NOTE: verify the jq path once with _payload-debug.sh before trusting this.
set -uo pipefail

INPUT=$(cat)

AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
[ -z "$AGENT" ] && exit 0

SKILL=$(printf '%s' "$INPUT" | jq -r '
  .tool_input.skill // .tool_input.name // .tool_input.command // .tool_input.skill_name // empty
' 2>/dev/null)
[ -z "$SKILL" ] && exit 0
SKILL="${SKILL#/}"
SKILL="${SKILL%% *}"
# Plugin skills arrive namespaced as <plugin>:<name>; match on the bare name.
SKILL="${SKILL##*:}"

case "$AGENT" in
  go-coder)
    ALLOWED="golang-error-handling golang-concurrency golang-context
             golang-structs-interfaces golang-design-patterns
             golang-data-structures golang-database golang-modernize
             golang-how-to golang-samber-do golang-grpc golang-swagger
             golang-observability incremental-implementation
             api-and-interface-design" ;;
  go-reviewer)
    ALLOWED="golang-error-handling golang-context
             golang-structs-interfaces golang-design-patterns
             golang-data-structures golang-database golang-grpc
             golang-security golang-performance code-review-and-quality
             code-simplification security-and-hardening" ;;
  go-qa-automation)
    ALLOWED="golang-benchmark golang-troubleshooting golang-concurrency
             golang-data-structures golang-database golang-grpc golang-safety
             test-driven-development debugging-and-error-recovery
             verification-before-completion" ;;
  improver)
    ALLOWED="skill-progressive-disclosure-design verification-before-completion
             systematic-debugging" ;;
  *)
    # Not one of this plugin's gated agents - do not interfere.
    exit 0 ;;
esac

for a in $ALLOWED; do
  [ "$SKILL" = "$a" ] && exit 0
done

printf "Skill '%s' is not in the allowlist for agent '%s'.\nAllowed: %s\n" \
  "$SKILL" "$AGENT" "$(echo $ALLOWED)" >&2
exit 2
