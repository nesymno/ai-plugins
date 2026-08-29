#!/usr/bin/env bash
# Standalone gate. go-reviewer runs this before reviewing anything.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

fail=0
run() {
  local name="$1"; shift
  local out
  if ! out=$("$@" 2>&1); then
    printf '=== %s FAILED ===\n%s\n\n' "$name" "$out"
    fail=1
  fi
}

run "gofmt"       sh -c 'test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }'
run "go build"    go build ./...
run "go vet"      go vet ./...
command -v golangci-lint >/dev/null 2>&1 && run "golangci-lint" golangci-lint run ./...
command -v govulncheck   >/dev/null 2>&1 && run "govulncheck"   govulncheck ./...

[ "$fail" -eq 0 ] && echo "precheck: clean"
exit "$fail"
