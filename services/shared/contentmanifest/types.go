package contentmanifest

type MapEntry struct {
	MapID             string   `json:"map_id"`
	DisplayName       string   `json:"display_name"`
	ModeID            string   `json:"mode_id"`
	RuleSetID         string   `json:"rule_set_id"`
	MatchFormatIDs    []string `json:"match_format_ids"`
	RequiredTeamCount int      `json:"required_team_count"`
	MaxPlayerCount    int      `json:"max_player_count"`
	CustomRoomEnabled bool     `json:"custom_room_enabled"`
	CasualEnabled     bool     `json:"casual_enabled"`
	RankedEnabled     bool     `json:"ranked_enabled"`
}

type ModeEntry struct {
	ModeID                string   `json:"mode_id"`
	DisplayName           string   `json:"display_name"`
	MatchFormatIDs        []string `json:"match_format_ids"`
	SelectableInMatchRoom bool     `json:"selectable_in_match_room"`
}

type RuleEntry struct {
	RuleSetID   string `json:"rule_set_id"`
	DisplayName string `json:"display_name"`
}

type MatchFormat struct {
	MatchFormatID            string   `json:"match_format_id"`
	RequiredPartySize        int      `json:"required_party_size"`
	ExpectedTotalPlayerCount int      `json:"expected_total_player_count"`
	LegalModeIDs             []string `json:"legal_mode_ids"`
	MapPoolResolutionPolicy  string   `json:"map_pool_resolution_policy"`
}

type Assets struct {
	DefaultCharacterID    string   `json:"default_character_id"`
	DefaultBubbleStyleID  string   `json:"default_bubble_style_id"`
	LegalCharacterIDs     []string `json:"legal_character_ids"`
	LegalCharacterSkinIDs []string `json:"legal_character_skin_ids"`
	LegalBubbleStyleIDs   []string `json:"legal_bubble_style_ids"`
	LegalBubbleSkinIDs    []string `json:"legal_bubble_skin_ids"`
}

type Manifest struct {
	SchemaVersion     int           `json:"schema_version"`
	GeneratedAtUnixMS int64         `json:"generated_at_unix_ms"`
	Maps              []MapEntry    `json:"maps"`
	Modes             []ModeEntry   `json:"modes"`
	Rules             []RuleEntry   `json:"rules"`
	MatchFormats      []MatchFormat `json:"match_formats"`
	Assets            Assets        `json:"assets"`
}
