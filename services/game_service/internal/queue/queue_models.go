package queue

type EnterQueueInput struct {
	AccountID          string
	ProfileID          string
	DeviceSessionID    string
	QueueType          string
	MatchFormatID      string
	ModeID             string
	RuleSetID          string
	PreferredMapPoolID string
}

type PartyQueueMemberInput struct {
	AccountID       string `json:"account_id"`
	ProfileID       string `json:"profile_id"`
	DeviceSessionID string `json:"device_session_id"`
	SeatIndex       int    `json:"seat_index"`
	RatingSnapshot  int    `json:"rating_snapshot,omitempty"`
}

type EnterPartyQueueInput struct {
	PartyRoomID     string
	QueueType       string
	MatchFormatID   string
	SelectedModeIDs []string
	Members         []PartyQueueMemberInput
}

type PartyQueueStatus struct {
	QueueState             string   `json:"queue_state"`
	QueueEntryID           string   `json:"queue_entry_id"`
	PartyRoomID            string   `json:"party_room_id"`
	QueueKey               string   `json:"queue_key"`
	QueueType              string   `json:"queue_type"`
	MatchFormatID          string   `json:"match_format_id"`
	SelectedModeIDs        []string `json:"selected_mode_ids"`
	AssignmentID           string   `json:"assignment_id"`
	AssignmentRevision     int      `json:"assignment_revision"`
	QueueStatusText        string   `json:"queue_status_text"`
	AssignmentStatusText   string   `json:"assignment_status_text"`
	EnqueueUnixSec         int64    `json:"enqueue_unix_sec"`
	LastHeartbeatUnixSec   int64    `json:"last_heartbeat_unix_sec"`
	ExpiresAtUnixSec       int64    `json:"expires_at_unix_sec"`
	RoomID                 string   `json:"room_id,omitempty"`
	RoomKind               string   `json:"room_kind,omitempty"`
	ServerHost             string   `json:"server_host,omitempty"`
	ServerPort             int      `json:"server_port,omitempty"`
	ModeID                 string   `json:"mode_id,omitempty"`
	RuleSetID              string   `json:"rule_set_id,omitempty"`
	MapID                  string   `json:"map_id,omitempty"`
	CaptainAccountID       string   `json:"captain_account_id,omitempty"`
	CaptainDeadlineUnixSec int64    `json:"captain_deadline_unix_sec,omitempty"`
	CommitDeadlineUnixSec  int64    `json:"commit_deadline_unix_sec,omitempty"`
	BattleID               string   `json:"battle_id,omitempty"`
	MatchID                string   `json:"match_id,omitempty"`
	AllocationState        string   `json:"allocation_state,omitempty"`
}

type QueueStatus struct {
	QueueState             string `json:"queue_state"`
	QueueEntryID           string `json:"queue_entry_id"`
	QueueKey               string `json:"queue_key"`
	AssignmentID           string `json:"assignment_id"`
	AssignmentRevision     int    `json:"assignment_revision"`
	QueueStatusText        string `json:"queue_status_text"`
	AssignmentStatusText   string `json:"assignment_status_text"`
	EnqueueUnixSec         int64  `json:"enqueue_unix_sec"`
	LastHeartbeatUnixSec   int64  `json:"last_heartbeat_unix_sec"`
	ExpiresAtUnixSec       int64  `json:"expires_at_unix_sec"`
	TicketRole             string `json:"ticket_role,omitempty"`
	RoomID                 string `json:"room_id,omitempty"`
	RoomKind               string `json:"room_kind,omitempty"`
	ServerHost             string `json:"server_host,omitempty"`
	ServerPort             int    `json:"server_port,omitempty"`
	ModeID                 string `json:"mode_id,omitempty"`
	RuleSetID              string `json:"rule_set_id,omitempty"`
	MapID                  string `json:"map_id,omitempty"`
	AssignedTeamID         int    `json:"assigned_team_id,omitempty"`
	CaptainAccountID       string `json:"captain_account_id,omitempty"`
	CaptainDeadlineUnixSec int64  `json:"captain_deadline_unix_sec,omitempty"`
	CommitDeadlineUnixSec  int64  `json:"commit_deadline_unix_sec,omitempty"`
}
