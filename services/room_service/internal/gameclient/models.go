package gameclient

type PartyMember struct {
	AccountID       string
	ProfileID       string
	TeamID          int
	CharacterID     string
	CharacterSkinID string
	BubbleStyleID   string
	BubbleSkinID    string
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
	OK                  bool
	QueueEntryID        string
	QueueState          string
	QueuePhase          string
	QueueTerminalReason string
	QueueStatusText     string
	StatusText          string
	ErrorCode           string
	UserMessage         string
}

type CancelPartyQueueInput struct {
	RoomID       string
	RoomKind     string
	QueueType    string
	QueueEntryID string
}

type CancelPartyQueueResult struct {
	OK                  bool
	QueueState          string
	QueuePhase          string
	QueueTerminalReason string
	QueueStatusText     string
	StatusText          string
	ErrorCode           string
	UserMessage         string
}

type GetPartyQueueStatusInput struct {
	RoomID       string
	RoomKind     string
	QueueEntryID string
}

type GetPartyQueueStatusResult struct {
	OK                   bool
	QueueState           string
	QueuePhase           string
	QueueTerminalReason  string
	QueueStatusText      string
	AssignmentStatusText string
	AllocationPhase      string
	AllocationReason     string
	BattleEntryReady     bool
	AssignmentID         string
	AssignmentRevision   int
	MatchID              string
	BattleID             string
	ServerHost           string
	ServerPort           int
	ErrorCode            string
	UserMessage          string
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
	OK                 bool
	AssignmentID       string
	AssignmentRevision int
	MatchID            string
	BattleID           string
	ServerHost         string
	ServerPort         int
	AllocationState    string
	Ready              bool
	ErrorCode          string
	UserMessage        string
}

type CommitAssignmentReadyInput struct {
	RoomID             string
	RoomKind           string
	AssignmentID       string
	AccountID          string
	ProfileID          string
	AssignmentRevision int
	BattleID           string
	MatchID            string
}

type GetBattleAssignmentStatusInput struct {
	RoomID        string
	RoomKind      string
	AssignmentID  string
	KnownRevision int64
}

type GetBattleAssignmentStatusResult struct {
	OK                 bool
	ErrorCode          string
	UserMessage        string
	RoomID             string
	AssignmentID       string
	AssignmentRevision int64
	MatchID            string
	BattleID           string
	ServerHost         string
	ServerPort         int32
	BattlePhase        string
	TerminalReason     string
	AllocationState    string
	StatusText         string
	BattleEntryReady   bool
	Finalized          bool
}

type CommitAssignmentReadyResult struct {
	OK             bool
	CommittedState string
	ErrorCode      string
	UserMessage    string
}

type ReapBattleInput struct {
	RoomID       string
	AssignmentID string
	BattleID     string
}

type ReapBattleResult struct {
	OK          bool
	BattleID    string
	Reaped      bool
	ErrorCode   string
	UserMessage string
}
