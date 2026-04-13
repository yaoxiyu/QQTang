package finalize

import "time"

type MemberResultInput struct {
	AccountID   string `json:"account_id"`
	ProfileID   string `json:"profile_id"`
	TeamID      int    `json:"team_id"`
	PeerID      int    `json:"peer_id"`
	Outcome     string `json:"outcome"`
	PlayerScore int    `json:"player_score"`
	TeamScore   int    `json:"team_score"`
	Placement   int    `json:"placement"`
}

type FinalizeInput struct {
	MatchID       string              `json:"match_id"`
	AssignmentID  string              `json:"assignment_id"`
	RoomID        string              `json:"room_id"`
	RoomKind      string              `json:"room_kind"`
	SeasonID      string              `json:"season_id"`
	ModeID        string              `json:"mode_id"`
	RuleSetID     string              `json:"rule_set_id"`
	MapID         string              `json:"map_id"`
	StartedAt     *time.Time          `json:"started_at"`
	FinishedAt    time.Time           `json:"finished_at"`
	FinishReason  string              `json:"finish_reason"`
	ScorePolicy   string              `json:"score_policy"`
	WinnerTeamIDs []int               `json:"winner_team_ids"`
	WinnerPeerIDs []int               `json:"winner_peer_ids"`
	ResultHash    string              `json:"result_hash"`
	MemberResults []MemberResultInput `json:"member_results"`
}

type SettlementSummary struct {
	ProfileCount     int `json:"profile_count"`
	SeasonPointTotal int `json:"season_point_total"`
	CareerXPTotal    int `json:"career_xp_total"`
	SoftGoldTotal    int `json:"soft_gold_total"`
}

type FinalizeResult struct {
	FinalizeState     string            `json:"finalize_state"`
	MatchID           string            `json:"match_id"`
	AssignmentID      string            `json:"assignment_id"`
	AlreadyCommitted  bool              `json:"already_committed"`
	ResultHash        string            `json:"result_hash"`
	SettlementSummary SettlementSummary `json:"settlement_summary"`
	FinalizedAt       time.Time         `json:"finalized_at"`
}

type MatchSummaryView struct {
	MatchID          string           `json:"match_id"`
	ProfileID        string           `json:"profile_id"`
	ServerSyncState  string           `json:"server_sync_state"`
	Outcome          string           `json:"outcome,omitempty"`
	RatingBefore     int              `json:"rating_before"`
	RatingDelta      int              `json:"rating_delta"`
	RatingAfter      int              `json:"rating_after"`
	RankTierAfter    string           `json:"rank_tier_after"`
	SeasonPointDelta int              `json:"season_point_delta"`
	CareerXPDelta    int              `json:"career_xp_delta"`
	GoldDelta        int              `json:"gold_delta"`
	RewardSummary    []map[string]any `json:"reward_summary"`
	CareerSummary    map[string]any   `json:"career_summary"`
	UpdatedAt        time.Time        `json:"updated_at"`
}
