package assignment

type GrantResult struct {
	AssignmentID           string `json:"assignment_id"`
	AssignmentRevision     int    `json:"assignment_revision"`
	GrantState             string `json:"grant_state"`
	MatchSource            string `json:"match_source"`
	QueueType              string `json:"queue_type"`
	TicketRole             string `json:"ticket_role"`
	RoomID                 string `json:"room_id"`
	RoomKind               string `json:"room_kind"`
	MatchID                string `json:"match_id"`
	SeasonID               string `json:"season_id"`
	ServerHost             string `json:"server_host"`
	ServerPort             int    `json:"server_port"`
	LockedMapID            string `json:"locked_map_id"`
	LockedRuleSetID        string `json:"locked_rule_set_id"`
	LockedModeID           string `json:"locked_mode_id"`
	AssignedTeamID         int    `json:"assigned_team_id"`
	ExpectedMemberCount    int    `json:"expected_member_count"`
	AutoReadyOnJoin        bool   `json:"auto_ready_on_join"`
	HiddenRoom             bool   `json:"hidden_room"`
	CaptainAccountID       string `json:"captain_account_id"`
	CaptainDeadlineUnixSec int64  `json:"captain_deadline_unix_sec"`
	CommitDeadlineUnixSec  int64  `json:"commit_deadline_unix_sec"`
}
