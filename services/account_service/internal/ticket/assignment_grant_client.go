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
)

var (
	ErrAssignmentGrantFailed    = errors.New("ROOM_TICKET_ASSIGNMENT_GRANT_FAILED")
	ErrAssignmentGrantForbidden = errors.New("ROOM_TICKET_ASSIGNMENT_GRANT_FORBIDDEN")
)

type AssignmentGrantResult struct {
	AssignmentID           string `json:"assignment_id"`
	AssignmentRevision     int    `json:"assignment_revision"`
	GrantState             string `json:"grant_state"`
	MatchSource            string `json:"match_source"`
	SeasonID               string `json:"season_id"`
	TicketRole             string `json:"ticket_role"`
	RoomID                 string `json:"room_id"`
	RoomKind               string `json:"room_kind"`
	MatchID                string `json:"match_id"`
	LockedMapID            string `json:"locked_map_id"`
	LockedRuleSetID        string `json:"locked_rule_set_id"`
	LockedModeID           string `json:"locked_mode_id"`
	AssignedTeamID         int    `json:"assigned_team_id"`
	ExpectedMemberCount    int    `json:"expected_member_count"`
	AutoReadyOnJoin        bool   `json:"auto_ready_on_join"`
	HiddenRoom             bool   `json:"hidden_room"`
	CaptainDeadlineUnixSec int64  `json:"captain_deadline_unix_sec"`
	CommitDeadlineUnixSec  int64  `json:"commit_deadline_unix_sec"`
}

type AssignmentGrantClient struct {
	baseURL        string
	internalSecret string
	httpClient     *http.Client
}

func NewAssignmentGrantClient(baseURL string, internalSecret string) *AssignmentGrantClient {
	return &AssignmentGrantClient{
		baseURL:        strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		internalSecret: internalSecret,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

func (c *AssignmentGrantClient) GetGrant(ctx context.Context, assignmentID string, accountID string, profileID string, roomKind string) (AssignmentGrantResult, error) {
	base, err := url.Parse(c.baseURL)
	if err != nil {
		return AssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrAssignmentGrantFailed, err)
	}
	base.Path = fmt.Sprintf("/internal/v1/assignments/%s/grant", assignmentID)
	query := base.Query()
	query.Set("account_id", accountID)
	query.Set("profile_id", profileID)
	query.Set("room_kind", roomKind)
	base.RawQuery = query.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base.String(), nil)
	if err != nil {
		return AssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrAssignmentGrantFailed, err)
	}
	req.Header.Set("X-Internal-Secret", c.internalSecret)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return AssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrAssignmentGrantFailed, err)
	}
	defer resp.Body.Close()

	var payload struct {
		OK        bool   `json:"ok"`
		ErrorCode string `json:"error_code"`
		Message   string `json:"message"`
		AssignmentGrantResult
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return AssignmentGrantResult{}, fmt.Errorf("%w: %v", ErrAssignmentGrantFailed, err)
	}
	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return AssignmentGrantResult{}, ErrAssignmentGrantForbidden
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 || !payload.OK {
		if payload.ErrorCode != "" {
			return AssignmentGrantResult{}, errors.New(payload.ErrorCode)
		}
		return AssignmentGrantResult{}, ErrAssignmentGrantFailed
	}
	return payload.AssignmentGrantResult, nil
}
