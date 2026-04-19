package manifest

import (
	"encoding/json"
	"fmt"
	"os"
)

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

type Loader struct {
	path     string
	manifest *Manifest
}

func LoadFromFile(path string) (*Loader, error) {
	if path == "" {
		return nil, fmt.Errorf("manifest path is empty")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read manifest: %w", err)
	}
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("decode manifest: %w", err)
	}
	if m.SchemaVersion <= 0 {
		return nil, fmt.Errorf("manifest schema_version is invalid")
	}
	return &Loader{path: path, manifest: &m}, nil
}

func (l *Loader) Path() string {
	if l == nil {
		return ""
	}
	return l.path
}

func (l *Loader) Manifest() *Manifest {
	if l == nil {
		return nil
	}
	return l.manifest
}

func (l *Loader) Ready() bool {
	return l != nil && l.manifest != nil && l.manifest.SchemaVersion > 0
}

func (l *Loader) FindMap(mapID string) *MapEntry {
	if l == nil || l.manifest == nil {
		return nil
	}
	for i := range l.manifest.Maps {
		if l.manifest.Maps[i].MapID == mapID {
			return &l.manifest.Maps[i]
		}
	}
	return nil
}

func (l *Loader) FirstMap() *MapEntry {
	if l == nil || l.manifest == nil || len(l.manifest.Maps) == 0 {
		return nil
	}
	return &l.manifest.Maps[0]
}

func (l *Loader) HasLegalCharacterID(characterID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	return contains(l.manifest.Assets.LegalCharacterIDs, characterID)
}

func (l *Loader) HasLegalCharacterSkinID(characterSkinID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	if characterSkinID == "" {
		return true
	}
	return contains(l.manifest.Assets.LegalCharacterSkinIDs, characterSkinID)
}

func (l *Loader) HasLegalBubbleStyleID(bubbleStyleID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	return contains(l.manifest.Assets.LegalBubbleStyleIDs, bubbleStyleID)
}

func (l *Loader) HasLegalBubbleSkinID(bubbleSkinID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	if bubbleSkinID == "" {
		return true
	}
	return contains(l.manifest.Assets.LegalBubbleSkinIDs, bubbleSkinID)
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
