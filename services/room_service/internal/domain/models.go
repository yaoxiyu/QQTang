package domain

type RoomSelection struct {
	MapID          string
	RuleSetID      string
	ModeID         string
	MatchFormatID  string
	SelectedModeID []string
}

type RoomLoadout struct {
	CharacterID     string
	CharacterSkinID string
	BubbleStyleID   string
	BubbleSkinID    string
}

type RoomMember struct {
	MemberID       string
	AccountID      string
	ProfileID      string
	PlayerName     string
	ConnectionID   string
	ReconnectToken string
	Ready          bool
	Loadout        RoomLoadout
}

type RoomQueueState struct {
	QueueType    string
	QueueState   string
	QueueEntryID string
}

type ResumeBinding struct {
	MemberID                string
	ReconnectToken          string
	ReconnectDeadlineUnixMS int64
}

type BattleHandoff struct {
	AssignmentID string
	BattleID     string
	MatchID      string
	ServerHost   string
	ServerPort   int
	Ready        bool
}

type RoomAggregate struct {
	RoomID             string
	RoomKind           string
	RoomDisplayName    string
	SnapshotRevision   int64
	Selection          RoomSelection
	Members            map[string]RoomMember
	Queue              RoomQueueState
	ResumeBindings     map[string]ResumeBinding
	BattleHandoffState BattleHandoff
	MaxPlayerCount     int
}
