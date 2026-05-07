package ticket

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"qqtang/services/shared/internalauth"
)

var (
	ErrBattleAssignmentGrantFailed    = errors.New("BATTLE_TICKET_ASSIGNMENT_GRANT_FAILED")
	ErrBattleAssignmentGrantForbidden = errors.New("BATTLE_TICKET_ASSIGNMENT_GRANT_FORBIDDEN")
)

type BattleAssignmentGrantResult struct {
	AssignmentID        string `json:"assignment_id"`
	BattleID            string `json:"battle_id"`
	MatchID             string `json:"match_id"`
	MapID               string `json:"map_id"`
	RuleSetID           string `json:"rule_set_id"`
	ModeID              string `json:"mode_id"`
	AssignedTeamID      int    `json:"assigned_team_id"`
	ExpectedMemberCount int    `json:"expected_member_count"`
	BattleServerHost    string `json:"battle_server_host"`
	BattleServerPort    int    `json:"battle_server_port"`
	AllocationState     string `json:"allocation_state"`
}

type BattleAssignmentGrantClient struct {
	baseURL      string
	keyID        string
	sharedSecret string
	httpClient   *http.Client
}

func NewBattleAssignmentGrantClient(baseURL string, keyID string, sharedSecret string) *BattleAssignmentGrantClient {
	return &BattleAssignmentGrantClient{
		baseURL:      strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		keyID:        keyID,
		sharedSecret: sharedSecret,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

func (c *BattleAssignmentGrantClient) GetGrant(ctx context.Context, assignmentID string, battleID string, accountID string, profileID string) (BattleAssignmentGrantResult, error) {
	base, err := url.Parse(c.baseURL)
	if err != nil {
		return BattleAssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrBattleAssignmentGrantFailed, err)
	}
	base.Path = fmt.Sprintf("/internal/v1/assignments/%s/grant", assignmentID)
	query := base.Query()
	query.Set("account_id", accountID)
	query.Set("profile_id", profileID)
	query.Set("battle_id", battleID)
	query.Set("ticket_type", "battle")
	base.RawQuery = query.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base.String(), nil)
	if err != nil {
		return BattleAssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrBattleAssignmentGrantFailed, err)
	}
	if err := internalauth.SignRequest(req, c.keyID, c.sharedSecret, nil, time.Now()); err != nil {
		return BattleAssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrBattleAssignmentGrantFailed, err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return BattleAssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrBattleAssignmentGrantFailed, err)
	}
	defer resp.Body.Close()

	var payload struct {
		OK        bool   `json:"ok"`
		ErrorCode string `json:"error_code"`
		Message   string `json:"message"`
		BattleAssignmentGrantResult
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return BattleAssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrBattleAssignmentGrantFailed, err)
	}
	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return BattleAssignmentGrantResult{}, ErrBattleAssignmentGrantForbidden
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 || !payload.OK {
		if payload.ErrorCode != "" {
			return BattleAssignmentGrantResult{}, errors.New(payload.ErrorCode)
		}
		return BattleAssignmentGrantResult{}, ErrBattleAssignmentGrantFailed
	}
	return payload.BattleAssignmentGrantResult, nil
}
