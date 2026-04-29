package dockerwarm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"qqtang/services/ds_manager_service/internal/internalhttp"
)

type AgentState struct {
	OK           bool   `json:"ok"`
	State        string `json:"state,omitempty"`
	LeaseID      string `json:"lease_id,omitempty"`
	BattleID     string `json:"battle_id,omitempty"`
	AssignmentID string `json:"assignment_id,omitempty"`
	MatchID      string `json:"match_id,omitempty"`
	BattlePort   int    `json:"battle_port,omitempty"`
	PID          int    `json:"pid,omitempty"`
}

type AgentClient interface {
	Health(ctx context.Context, endpoint string) error
	State(ctx context.Context, endpoint string) (AgentState, error)
	Assign(ctx context.Context, endpoint string, req AgentAssignRequest) (AgentState, error)
	Reset(ctx context.Context, endpoint string) (AgentState, error)
}

type AgentAssignRequest struct {
	LeaseID             string `json:"lease_id"`
	BattleID            string `json:"battle_id"`
	AssignmentID        string `json:"assignment_id"`
	MatchID             string `json:"match_id"`
	ExpectedMemberCount int    `json:"expected_member_count"`
	AdvertiseHost       string `json:"advertise_host"`
	AdvertisePort       int    `json:"advertise_port"`
	GameServiceBaseURL  string `json:"game_service_base_url"`
	DSMBaseURL          string `json:"dsm_base_url"`
	ReadyTimeoutMS      int    `json:"ready_timeout_ms"`
}

type FakeAgentClient struct {
	mu             sync.Mutex
	states         map[string]AgentState
	Failures       map[string]error
	AssignFailures map[string]error
}

type HTTPAgentClient struct {
	httpClient   *http.Client
	authKeyID    string
	authSecret   string
	requestClock func() time.Time
}

func NewHTTPAgentClient(authKeyID string, authSecret string) *HTTPAgentClient {
	return &HTTPAgentClient{
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
		authKeyID:    authKeyID,
		authSecret:   authSecret,
		requestClock: func() time.Time { return time.Now().UTC() },
	}
}

func (c *HTTPAgentClient) Health(ctx context.Context, endpoint string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"/healthz", nil)
	if err != nil {
		return err
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("agent health returned status %d", resp.StatusCode)
	}
	return nil
}

func (c *HTTPAgentClient) State(ctx context.Context, endpoint string) (AgentState, error) {
	var result AgentState
	if err := c.doJSON(ctx, http.MethodGet, endpoint+"/internal/v1/agent/state", nil, &result); err != nil {
		return AgentState{}, err
	}
	return result, nil
}

func (c *HTTPAgentClient) Assign(ctx context.Context, endpoint string, req AgentAssignRequest) (AgentState, error) {
	var result AgentState
	if err := c.doJSON(ctx, http.MethodPost, endpoint+"/internal/v1/agent/assign", req, &result); err != nil {
		return AgentState{}, err
	}
	return result, nil
}

func (c *HTTPAgentClient) Reset(ctx context.Context, endpoint string) (AgentState, error) {
	var result AgentState
	if err := c.doJSON(ctx, http.MethodPost, endpoint+"/internal/v1/agent/reset", map[string]any{}, &result); err != nil {
		return AgentState{}, err
	}
	return result, nil
}

func (c *HTTPAgentClient) doJSON(ctx context.Context, method string, url string, payload any, dst any) error {
	body := []byte(nil)
	var err error
	if payload != nil {
		body, err = json.Marshal(payload)
		if err != nil {
			return err
		}
	}
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if err := internalhttp.SignRequest(req, c.authKeyID, c.authSecret, body, c.requestClock()); err != nil {
		return err
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return err
	}
	if len(respBody) > 0 {
		if err := json.Unmarshal(respBody, dst); err != nil {
			return fmt.Errorf("agent response parse failed: %w", err)
		}
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("agent request failed status=%d body=%s", resp.StatusCode, string(respBody))
	}
	return nil
}

func NewFakeAgentClient() *FakeAgentClient {
	return &FakeAgentClient{
		states:         map[string]AgentState{},
		Failures:       map[string]error{},
		AssignFailures: map[string]error{},
	}
}

func (c *FakeAgentClient) SetState(endpoint string, state AgentState) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.states[endpoint] = state
}

func (c *FakeAgentClient) Health(_ context.Context, endpoint string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.Failures[endpoint]; err != nil {
		return err
	}
	return nil
}

func (c *FakeAgentClient) State(_ context.Context, endpoint string) (AgentState, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.Failures[endpoint]; err != nil {
		return AgentState{}, err
	}
	state, ok := c.states[endpoint]
	if !ok {
		return AgentState{OK: true, State: "idle"}, nil
	}
	return state, nil
}

func (c *FakeAgentClient) Assign(_ context.Context, endpoint string, req AgentAssignRequest) (AgentState, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.AssignFailures[endpoint]; err != nil {
		return AgentState{}, err
	}
	if req.LeaseID == "" || req.BattleID == "" {
		return AgentState{}, fmt.Errorf("lease_id and battle_id are required")
	}
	state := AgentState{
		OK:           true,
		State:        "godot_started",
		LeaseID:      req.LeaseID,
		BattleID:     req.BattleID,
		AssignmentID: req.AssignmentID,
		MatchID:      req.MatchID,
		BattlePort:   req.AdvertisePort,
		PID:          123,
	}
	c.states[endpoint] = state
	return state, nil
}

func (c *FakeAgentClient) Reset(_ context.Context, endpoint string) (AgentState, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.Failures[endpoint]; err != nil {
		return AgentState{}, err
	}
	state := AgentState{OK: true, State: "idle"}
	c.states[endpoint] = state
	return state, nil
}
