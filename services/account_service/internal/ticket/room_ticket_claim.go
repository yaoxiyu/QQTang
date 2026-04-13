package ticket

type RoomTicketClaim struct {
	TicketID                string   `json:"ticket_id"`
	AccountID               string   `json:"account_id"`
	ProfileID               string   `json:"profile_id"`
	DeviceSessionID         string   `json:"device_session_id"`
	Purpose                 string   `json:"purpose"`
	RoomID                  string   `json:"room_id"`
	RoomKind                string   `json:"room_kind"`
	RequestedMatchID        string   `json:"requested_match_id"`
	AssignmentID            string   `json:"assignment_id"`
	MatchSource             string   `json:"match_source"`
	SeasonID                string   `json:"season_id"`
	LockedMapID             string   `json:"locked_map_id"`
	LockedRuleSetID         string   `json:"locked_rule_set_id"`
	LockedModeID            string   `json:"locked_mode_id"`
	AssignedTeamID          int      `json:"assigned_team_id"`
	ExpectedMemberCount     int      `json:"expected_member_count"`
	AutoReadyOnJoin         bool     `json:"auto_ready_on_join"`
	HiddenRoom              bool     `json:"hidden_room"`
	DisplayName             string   `json:"display_name"`
	AllowedCharacterIDs     []string `json:"allowed_character_ids"`
	AllowedCharacterSkinIDs []string `json:"allowed_character_skin_ids"`
	AllowedBubbleStyleIDs   []string `json:"allowed_bubble_style_ids"`
	AllowedBubbleSkinIDs    []string `json:"allowed_bubble_skin_ids"`
	IssuedAtUnixSec         int64    `json:"issued_at_unix_sec"`
	ExpireAtUnixSec         int64    `json:"expire_at_unix_sec"`
	Nonce                   string   `json:"nonce"`
	Signature               string   `json:"signature,omitempty"`
}
