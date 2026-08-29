#!/usr/bin/env bash
# PreToolUse:Bash - block mutations of live infrastructure.
#
# Wired at plugin scope; enforces only for the infra agents (.agent_type in
# devops, devops-analyzer). This is a denylist and denylists leak. Pair it with
# permissions.deny in the host project's settings.json, which Claude Code
# enforces itself.
set -uo pipefail

INPUT=$(cat)

AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
case "$AGENT" in
  devops|devops-analyzer) ;;
  *) exit 0 ;;
esac

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

deny() {
  printf 'BLOCKED: %s\nEdit the IaC and hand the human an APPLY block instead.\n' "$1" >&2
  exit 2
}

if printf '%s' "$CMD" | grep -qiE '\bkubectl\b.*\b(apply|create|delete|patch|replace|edit|scale|annotate|label|cordon|drain|uncordon|taint|rollout|exec|port-forward|cp|attach)\b'; then
  printf '%s' "$CMD" | grep -qE '\-\-dry-run' || deny "kubectl mutation."
fi

printf '%s' "$CMD" | grep -qiE '\bhelm\b.*\b(install|upgrade|uninstall|delete|rollback)\b'            && deny "helm mutation."
printf '%s' "$CMD" | grep -qiE '\bterraform\b.*\b(apply|destroy|import|taint|state[[:space:]]+(rm|mv|push))\b' && deny "terraform mutation."
printf '%s' "$CMD" | grep -qiE '\btofu\b.*\b(apply|destroy)\b'                                        && deny "opentofu mutation."
printf '%s' "$CMD" | grep -qiE '\b(docker|podman)[[:space:]]+push\b'                                  && deny "image push."
printf '%s' "$CMD" | grep -qiE '\bgh[[:space:]]+(workflow[[:space:]]+run|release[[:space:]]+create|pr[[:space:]]+merge)\b' && deny "github publish action."
printf '%s' "$CMD" | grep -qiE '\b(aws|gcloud|az)\b.*\b(delete|remove|rm|terminate|destroy)\b'        && deny "cloud deletion."
printf '%s' "$CMD" | grep -qiE '\bgit[[:space:]]+(push|reset[[:space:]]+--hard)\b'                    && deny "git push or hard reset."
printf '%s' "$CMD" | grep -qiE '\bflux\b.*\breconcile\b|\bargocd\b.*\b(app[[:space:]]+sync|app[[:space:]]+delete)\b' && deny "gitops force-sync."

# Shapes whose effect cannot be verified statically.
printf '%s' "$CMD" | grep -qE '\|[[:space:]]*(sh|bash)\b|\bxargs\b.*\b(kubectl|helm|terraform)\b|\beval\b' \
  && deny "unverifiable command shape."

exit 0
