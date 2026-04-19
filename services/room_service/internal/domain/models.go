package domain

type RoomSelection struct {
	MapID           string
	RuleSetID       string
	ModeID          string
	MatchFormatID   string
	SelectedModeIDs []string
}

type RoomLoadout struct {
	CharacterID     string
	CharacterSkinID string
	BubbleStyleID   string
	BubbleSkinID    string
}

type RoomMember struct {
	MemberID        string
	AccountID       string
	ProfileID       string
	PlayerName      string
	TeamID          int
	ConnectionState string
	ConnectionID    string
	ReconnectToken  string
	Ready           bool
	Loadout         RoomLoadout
}

type RoomQueueState struct {
	QueueType    string
	QueueState   string
	QueueEntryID string
	StatusText   string
	ErrorCode    string
	UserMessage  string
}

type ResumeBinding struct {
	MemberID                string
	ReconnectToken          string
	ReconnectDeadlineUnixMS int64
}

type BattleHandoff struct {
	AssignmentID    string
	BattleID        string
	MatchID         string
	ServerHost      string
	ServerPort      int
	Ready           bool
	AllocationState string
}

type RoomAggregate struct {
	RoomID             string
	RoomKind           string
	RoomDisplayName    string
	LifecycleState     string
	SnapshotRevision   int64
	Selection          RoomSelection
	Members            map[string]RoomMember
	Queue              RoomQueueState
	ResumeBindings     map[string]ResumeBinding
	BattleHandoffState BattleHandoff
	MaxPlayerCount     int
}
