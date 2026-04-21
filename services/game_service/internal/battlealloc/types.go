package battlealloc

type AllocateInput struct {
	AssignmentID        string
	BattleID            string
	MatchID             string
	SourceRoomID        string
	SourceRoomKind      string
	ModeID              string
	RuleSetID           string
	MapID               string
	ExpectedMemberCount int
	HostHint            string
	RoomReturnPolicy    string
}

type AllocateResult struct {
	BattleID        string
	DSInstanceID    string
	ServerHost      string
	ServerPort      int
	AllocationState string
}

type ManualRoomBattleInput struct {
	SourceRoomID        string
	SourceRoomKind      string
	ModeID              string
	RuleSetID           string
	MapID               string
	ExpectedMemberCount int
	Members             []ManualRoomMember
	HostHint            string
}

type ManualRoomMember struct {
	AccountID      string
	ProfileID      string
	AssignedTeamID int
}

type ManualRoomBattleResult struct {
	AssignmentID    string
	BattleID        string
	MatchID         string
	DSInstanceID    string
	ServerHost      string
	ServerPort      int
	AllocationState string
}

type BattleManifest struct {
	AssignmentID        string
	BattleID            string
	MatchID             string
	SourceRoomID        string
	SourceRoomKind      string
	SeasonID            string
	MapID               string
	RuleSetID           string
	ModeID              string
	ExpectedMemberCount int
	Members             []ManifestMember
}

type ManifestMember struct {
	AccountID      string
	ProfileID      string
	AssignedTeamID int
}
