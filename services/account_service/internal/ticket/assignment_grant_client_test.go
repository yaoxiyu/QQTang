package ticket

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"qqtang/services/account_service/internal/internalhttp"
)

func TestAssignmentGrantClientSignsInternalRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Internal-Secret") != "" {
			t.Fatal("legacy X-Internal-Secret header must not be sent")
		}
		for _, key := range []string{
			internalhttp.HeaderKeyID,
			internalhttp.HeaderTimestamp,
			internalhttp.HeaderNonce,
			internalhttp.HeaderBodySHA256,
			internalhttp.HeaderSignature,
		} {
			if r.Header.Get(key) == "" {
				t.Fatalf("missing internal auth header %s", key)
			}
		}
		if r.Header.Get(internalhttp.HeaderKeyID) != "primary" {
			t.Fatalf("unexpected key id: %s", r.Header.Get(internalhttp.HeaderKeyID))
		}
		if r.Header.Get(internalhttp.HeaderBodySHA256) != internalhttp.BodySHA256Hex(nil) {
			t.Fatalf("unexpected empty body hash: %s", r.Header.Get(internalhttp.HeaderBodySHA256))
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"ok":                    true,
			"assignment_id":         "assign_a",
			"assignment_revision":   1,
			"grant_state":           "granted",
			"expected_member_count": 4,
		})
	}))
	defer server.Close()

	client := NewAssignmentGrantClient(server.URL, "primary", "shared-secret")
	result, err := client.GetGrant(context.Background(), "assign_a", "account_a", "profile_a", "ranked_match_room")
	if err != nil {
		t.Fatalf("GetGrant returned error: %v", err)
	}
	if result.AssignmentID != "assign_a" || result.ExpectedMemberCount != 4 {
		t.Fatalf("unexpected grant result: %+v", result)
	}
}
