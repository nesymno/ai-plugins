package fixtures

import "testing"

func TestHonest(t *testing.T) {
	if got, want := 2+2, 4; got != want {
		t.Fatalf("got %d, want %d", got, want)
	}
}
