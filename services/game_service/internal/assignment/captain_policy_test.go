package assignment

import "testing"

func TestNextCaptainAccountIDReElectsNextMember(t *testing.T) {
	members := []string{"account_a", "account_b", "account_c"}

	if next := NextCaptainAccountID("account_a", members); next != "account_b" {
		t.Fatalf("expected captain to move to account_b, got %s", next)
	}
	if next := NextCaptainAccountID("account_c", members); next != "account_a" {
		t.Fatalf("expected captain selection to wrap to account_a, got %s", next)
	}
	if next := NextCaptainAccountID("missing", members); next != "account_a" {
		t.Fatalf("expected missing captain to fall back to first member, got %s", next)
	}
}
