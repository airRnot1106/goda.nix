package reverse

import (
	"context"
	"testing"
)

func TestReverse(t *testing.T) {
	got, err := New().Handlers()["reverse"](context.Background(), nil, []any{"goda"})
	if err != nil {
		t.Fatal(err)
	}
	if got != "adog" {
		t.Fatalf("reverse(goda) = %v, want adog", got)
	}
}

func TestReverseRejectsANumber(t *testing.T) {
	if _, err := New().Handlers()["reverse"](context.Background(), nil, []any{1}); err == nil {
		t.Fatal("reverse(1) returned no error")
	}
}
