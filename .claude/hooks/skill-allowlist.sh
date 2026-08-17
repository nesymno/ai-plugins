#!/usr/bin/env bash
# PreToolUse:Skill - restrict which skills an agent may load lazily.
# Usage in frontmatter:
#   command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/skill-allowlist.sh <agent-name>"
#
# NOTE: verify the jq path once with _payload-debug.sh before trusting this.
set -uo pipefail

AGENT="${1:?agent name required}"
INPUT=$(cat)

SKILL=$(printf '%s' "$INPUT" | jq -r '
  .tool_input.skill // .tool_input.name // .tool_input.command // .tool_input.skill_name // empty
' 2>/dev/null)

[ -z "$SKILL" ] && exit 0
SKILL="${SKILL#/}"
SKILL="${SKILL%% *}"

case "$AGENT" in
  task-composer)
    ALLOWED="spec-driven-development interview-me brainstorming" ;;
  go-coder)
    ALLOWED="golang-error-handling golang-concurrency golang-context
             golang-structs-interfaces golang-design-patterns
             golang-data-structures golang-database golang-modernize
             golang-how-to golang-samber-do golang-grpc golang-swagger
             golang-observability incremental-implementation
             api-and-interface-design" ;;
  reviewer)
    ALLOWED="golang-error-handling golang-samber-oops golang-context
             golang-structs-interfaces golang-design-patterns
             golang-data-structures golang-database golang-grpc
             golang-security golang-performance code-review-and-quality
             code-simplification security-and-hardening" ;;
  qa-automation)
    ALLOWED="golang-benchmark golang-troubleshooting golang-concurrency
             golang-data-structures golang-database golang-grpc golang-safety
             test-driven-development debugging-and-error-recovery
             verification-before-completion" ;;
  devops)
    ALLOWED="conventional-git golang-continuous-integration
             golang-dependency-management golang-lint golang-spf13-viper
             ci-cd-and-automation deprecation-and-migration
             snyk-agent-scan-compliance" ;;
  devops-diag)
    ALLOWED="promql-cli golang-observability golang-troubleshooting
             systematic-debugging observability-and-instrumentation" ;;
  doc-writer)
    ALLOWED="documentation-and-adrs golang-swagger golang-grpc
             golang-observability" ;;
  skill-smith)
    ALLOWED="skill-progressive-disclosure-design verification-before-completion
             systematic-debugging" ;;
  *)
    echo "skill-allowlist: unknown agent '$AGENT' - refusing by default" >&2
    exit 2 ;;
esac

for a in $ALLOWED; do
  [ "$SKILL" = "$a" ] && exit 0
done

printf "Skill '%s' is not in the allowlist for agent '%s'.\nAllowed: %s\n" \
  "$SKILL" "$AGENT" "$(echo $ALLOWED)" >&2
exit 2
