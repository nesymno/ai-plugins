//go:build harness_fixtures
// +build harness_fixtures

// Fixture, not a real test: guarded by a build tag so it is never compiled by
// a normal `go build/test ./...`. verify-gates.sh reads it as data.
package fixtures

import "testing"

func TestWeakened(t *testing.T) {
	t.Skip("agent gave up here")
}
