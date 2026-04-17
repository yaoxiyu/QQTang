package battlealloc

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"qqtang/services/game_service/internal/internalhttp"
)

func TestRequestDSAllocationSignsInternalAuthHeaders(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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
		if got := r.Header.Get(internalhttp.HeaderKeyID); got != "primary" {
			t.Fatalf("unexpected key id: %s", got)
		}
		if legacy := r.Header.Get("X-Internal-Secret"); legacy != "" {
			t.Fatalf("legacy header must not be sent, got %s", legacy)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"ok":             true,
			"ds_instance_id": "ds_1",
			"server_host":    "127.0.0.1",
			"server_port":    19010,
		})
	}))
	defer server.Close()

	svc := NewService(nil, nil, server.URL, "primary", "shared-secret")
	result, err := svc.requestDSAllocation(context.Background(), AllocateInput{
		AssignmentID:        "assign_1",
		BattleID:            "battle_1",
		MatchID:             "match_1",
		ExpectedMemberCount: 4,
	})
	if err != nil {
		t.Fatalf("requestDSAllocation returned error: %v", err)
	}
	if !result.OK || result.DSInstanceID != "ds_1" {
		t.Fatalf("unexpected ds allocation result: %+v", result)
	}
}
