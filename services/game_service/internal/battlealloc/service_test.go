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
	var requestBody map[string]any
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
		if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
			t.Fatalf("decode request body: %v", err)
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
		WaitReady:           true,
	})
	if err != nil {
		t.Fatalf("requestDSAllocation returned error: %v", err)
	}
	if !result.OK || result.DSInstanceID != "ds_1" {
		t.Fatalf("unexpected ds allocation result: %+v", result)
	}
	if requestBody["wait_ready"] != true {
		t.Fatalf("expected wait_ready=true in allocation request, got %#v", requestBody["wait_ready"])
	}
}

func TestRequestDSBattleStatusSignsInternalAuthHeaders(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/internal/v1/battles/battle_1" {
			t.Fatalf("unexpected request %s %s", r.Method, r.URL.Path)
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
		_ = json.NewEncoder(w).Encode(map[string]any{
			"ok":               true,
			"ds_instance_id":   "ds_1",
			"allocation_state": "ready",
			"server_host":      "qqt-ds-slot-001",
			"server_port":      9000,
		})
	}))
	defer server.Close()

	svc := NewService(nil, nil, server.URL, "primary", "shared-secret")
	result, err := svc.requestDSBattleStatus(context.Background(), "battle_1")
	if err != nil {
		t.Fatalf("requestDSBattleStatus returned error: %v", err)
	}
	if !result.OK || result.ServerHost != "qqt-ds-slot-001" || result.ServerPort != 9000 {
		t.Fatalf("unexpected ds status result: %+v", result)
	}
}
