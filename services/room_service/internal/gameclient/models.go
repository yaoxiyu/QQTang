package gameclient

type PartyMember struct {
	AccountID string
	ProfileID string
	TeamID    int
}

type EnterPartyQueueInput struct {
	RoomID          string
	RoomKind        string
	QueueType       string
	MatchFormatID   string
	SelectedModeIDs []string
	Members         []PartyMember
}

type EnterPartyQueueResult struct {
	OK           bool
	QueueEntryID string
	QueueState   string
	StatusText   string
	ErrorCode    string
	UserMessage  string
}

type CancelPartyQueueInput struct {
	RoomID       string
	RoomKind     string
	QueueType    string
	QueueEntryID string
}

type CancelPartyQueueResult struct {
	OK          bool
	QueueState  string
	StatusText  string
	ErrorCode   string
	UserMessage string
}

type GetPartyQueueStatusInput struct {
	RoomID       string
	RoomKind     string
	QueueEntryID string
}

type GetPartyQueueStatusResult struct {
	OK           bool
	QueueState   string
	AssignmentID string
	MatchID      string
	BattleID     string
	ServerHost   string
	ServerPort   int
	ErrorCode    string
	UserMessage  string
}

type CreateManualRoomBattleInput struct {
	RoomID    string
	RoomKind  string
	MapID     string
	ModeID    string
	RuleSetID string
	Members   []PartyMember
}

type CreateManualRoomBattleResult struct {
	OK              bool
	AssignmentID    string
	MatchID         string
	BattleID        string
	ServerHost      string
	ServerPort      int
	AllocationState string
	Ready           bool
	ErrorCode       string
	UserMessage     string
}

type CommitAssignmentReadyInput struct {
	RoomID       string
	RoomKind     string
	AssignmentID string
	BattleID     string
	MatchID      string
}

type CommitAssignmentReadyResult struct {
	OK             bool
	CommittedState string
	ErrorCode      string
	UserMessage    string
}
