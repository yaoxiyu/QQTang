package roomapp

import (
	"errors"
	"sync/atomic"

	"qqtang/services/room_service/internal/domain"
)

var (
	ErrInvalidTicket      = errors.New("invalid room ticket")
	ErrInvalidLoadout     = errors.New("invalid loadout")
	ErrInvalidSelection   = errors.New("invalid room selection")
	ErrRoomNotFound       = errors.New("room not found")
	ErrRoomNotJoinable    = errors.New("room not joinable")
	ErrMemberNotFound     = errors.New("member not found")
	ErrReconnectForbidden = errors.New("reconnect token mismatch")
	ErrNotRoomOwner       = errors.New("room owner required")
	ErrMatchRoomOnly      = errors.New("match room required")
	ErrMembersNotReady    = errors.New("all members must be ready")
	ErrQueueStateInvalid  = errors.New("queue state does not allow enter queue")
	ErrRoomPhaseInvalid   = errors.New("room phase does not allow operation")
	ErrMemberPhaseInvalid = errors.New("member phase does not allow operation")
	ErrPartySizeMismatch  = errors.New("MATCHMAKING_PARTY_SIZE_MISMATCH")
	ErrManualRoomOnly     = errors.New("manual room required")
	ErrInvalidRoomKind    = errors.New("invalid room kind")
)

type Loadout struct {
	CharacterID   string
	BubbleStyleID string
}

type Selection struct {
	MapID           string
	RuleSetID       string
	ModeID          string
	MatchFormatID   string
	SelectedModeIDs []string
}

type CreateRoomInput struct {
	RoomKind        string
	RoomDisplayName string
	RoomTicket      string
	AccountID       string
	ProfileID       string
	PlayerName      string
	ConnectionID    string
	Loadout         Loadout
	Selection       Selection
}

type JoinRoomInput struct {
	RoomID       string
	RoomTicket   string
	AccountID    string
	ProfileID    string
	PlayerName   string
	ConnectionID string
	Loadout      Loadout
}

type ResumeRoomInput struct {
	RoomID         string
	MemberID       string
	ReconnectToken string
	ConnectionID   string
	RoomTicket     string
}

type LeaveRoomInput struct {
	RoomID   string
	MemberID string
}

type UpdateProfileInput struct {
	RoomID     string
	MemberID   string
	PlayerName string
	TeamID     int
	Loadout    Loadout
}

type UpdateSelectionInput struct {
	RoomID          string
	MemberID        string
	Selection       Selection
	OpenSlotIndices []int
}

type UpdateMatchRoomConfigInput struct {
	RoomID          string
	MemberID        string
	MatchFormatID   string
	SelectedModeIDs []string
}

type EnterMatchQueueInput struct {
	RoomID   string
	MemberID string
}

type CancelMatchQueueInput struct {
	RoomID   string
	MemberID string
}

type StartManualRoomBattleInput struct {
	RoomID   string
	MemberID string
}

type AckBattleEntryInput struct {
	RoomID       string
	MemberID     string
	AssignmentID string
	BattleID     string
	MatchID      string
}

type ToggleReadyInput struct {
	RoomID   string
	MemberID string
}

type SnapshotProjection struct {
	RoomID               string
	RoomKind             string
	RoomDisplayName      string
	LifecycleState       string
	RoomPhase            string
	RoomPhaseReason      string
	SnapshotRevision     int64
	OwnerMemberID        string
	Selection            domain.RoomSelection
	Members              []domain.RoomMember
	MaxPlayerCount       int
	OpenSlotIndices      []int
	QueuePhase           string
	QueueTerminalReason  string
	QueueStatusText      string
	QueueErrorCode       string
	QueueUserMessage     string
	QueueEntryID         string
	BattlePhase          string
	BattleTerminalReason string
	BattleStatusText     string
	Capabilities         domain.RoomCapabilitySet
	QueueState           domain.RoomQueueState
	BattleHandoff        domain.BattleHandoff
}

type QueueStatusSyncResult struct {
	RoomID   string
	Snapshot *SnapshotProjection
}

type queueSyncTarget struct {
	roomID       string
	roomKind     string
	queueEntryID string
}

type battleSyncTarget struct {
	roomID             string
	roomKind           string
	assignmentID       string
	assignmentRevision int
}

type battleReapRequest struct {
	roomID       string
	assignmentID string
	battleID     string
	reason       string
}

type ControlPlaneMetrics struct {
	manualBattleAssignmentSyncCount        atomic.Int64
	manualBattleQueueStatusCallCount       atomic.Int64
	battleAssignmentStatusErrorCount       atomic.Int64
	battleAssignmentRevisionStaleDropCount atomic.Int64
	queueSyncTargetCount                   atomic.Int64
	battleSyncTargetCount                  atomic.Int64
	queueStateManualRoomWriteCount         atomic.Int64
}
