package fixtures

import "testing"

func TestNeedsDocker(t *testing.T) {
	t.Skip("no docker available") // ALLOW-SKIP: integration needs testcontainers
}
