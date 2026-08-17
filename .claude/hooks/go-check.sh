#!/usr/bin/env bash
# PostToolUse:Edit|Write - fast Go gate after every edit.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in *.go) ;; "") ;; *) exit 0 ;; esac

fail=0
out=""

if ! gofmt_out=$(gofmt -l . 2>&1) || [ -n "$gofmt_out" ]; then
  out="${out}=== gofmt ===
${gofmt_out}
"; fail=1
fi

if ! build_out=$(go build ./... 2>&1); then
  out="${out}=== go build ===
${build_out}
"; fail=1
fi

if [ "$fail" -eq 0 ] && ! vet_out=$(go vet ./... 2>&1); then
  out="${out}=== go vet ===
${vet_out}
"; fail=1
fi

if [ "$fail" -eq 0 ] && command -v golangci-lint >/dev/null 2>&1; then
  if ! lint_out=$(golangci-lint run ./... 2>&1); then
    out="${out}=== golangci-lint ===
${lint_out}
"; fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  printf '%s\nFix these before continuing. Do not suppress with nolint.\n' "$out" >&2
  exit 2
fi
exit 0
