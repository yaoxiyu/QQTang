package ticket

import "testing"

func TestRandomCharacterPlaceholderIsAllowedSelection(t *testing.T) {
	owned := []string{"10101", "10201"}

	if !isAllowedCharacterSelection(owned, randomCharacterPlaceholderID) {
		t.Fatalf("random placeholder should be allowed without ownership")
	}
	if !isAllowedCharacterSelection(owned, "10101") {
		t.Fatalf("owned character should remain allowed")
	}
	if isAllowedCharacterSelection(owned, "99999") {
		t.Fatalf("unowned regular character should not be allowed")
	}
}

func TestAllowedCharactersIncludeRandomPlaceholder(t *testing.T) {
	owned := []string{"10101", "10201"}
	allowed := withRandomCharacterPlaceholder(owned)

	if !contains(allowed, randomCharacterPlaceholderID) {
		t.Fatalf("allowed character ids should include random placeholder")
	}
	if len(owned) != 2 {
		t.Fatalf("owned slice should not be mutated")
	}
}
