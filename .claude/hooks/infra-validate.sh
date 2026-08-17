#!/usr/bin/env bash
# PostToolUse:Edit|Write - validate infra files after every edit.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

fail=0; out=""
note() { out="${out}=== $1 ===
$2
"; fail=1; }

case "$FILE" in
  *.tf|*.tfvars)
    command -v terraform >/dev/null 2>&1 && {
      r=$(terraform fmt -check "$FILE" 2>&1) || note "terraform fmt" "$r"
      r=$(terraform validate 2>&1)           || note "terraform validate" "$r"
    } ;;
  *.yaml|*.yml)
    case "$FILE" in
      *.github/workflows/*)
        command -v actionlint >/dev/null 2>&1 && { r=$(actionlint "$FILE" 2>&1) || note "actionlint" "$r"; } ;;
      *)
        command -v yamllint  >/dev/null 2>&1 && { r=$(yamllint -s "$FILE" 2>&1) || note "yamllint" "$r"; }
        command -v kubeconform >/dev/null 2>&1 && { r=$(kubeconform -strict -summary "$FILE" 2>&1) || note "kubeconform" "$r"; } ;;
    esac ;;
  */Dockerfile|Dockerfile*|*.dockerfile)
    command -v hadolint >/dev/null 2>&1 && { r=$(hadolint "$FILE" 2>&1) || note "hadolint" "$r"; } ;;
  *.sh)
    command -v shellcheck >/dev/null 2>&1 && { r=$(shellcheck "$FILE" 2>&1) || note "shellcheck" "$r"; } ;;
esac

if [ "$fail" -ne 0 ]; then
  printf '%s\nFix these before continuing.\n' "$out" >&2
  exit 2
fi
exit 0
