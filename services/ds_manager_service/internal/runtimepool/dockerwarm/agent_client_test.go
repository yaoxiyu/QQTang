package dockerwarm

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"qqtang/services/ds_manager_service/internal/auth"
)

func TestHTTPAgentClientSignsInternalRequests(t *testing.T) {
	internalAuth := auth.NewInternalAuth("primary", "agent-secret", time.Minute)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/healthz":
			_, _ = w.Write([]byte(`{"ok":true}`))
			return
		case "/internal/v1/agent/state":
			if err := internalAuth.ValidateRequest(r); err != nil {
				w.WriteHeader(http.StatusUnauthorized)
				_, _ = w.Write([]byte(`{"ok":false}`))
				return
			}
			_ = json.NewEncoder(w).Encode(AgentState{OK: true, State: "idle", BattlePort: 9000})
			return
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()

	client := NewHTTPAgentClient("primary", "agent-secret")
	if err := client.Health(t.Context(), server.URL); err != nil {
		t.Fatalf("Health returned error: %v", err)
	}
	state, err := client.State(t.Context(), server.URL)
	if err != nil {
		t.Fatalf("State returned error: %v", err)
	}
	if state.State != "idle" || state.BattlePort != 9000 {
		t.Fatalf("unexpected state: %+v", state)
	}
}
