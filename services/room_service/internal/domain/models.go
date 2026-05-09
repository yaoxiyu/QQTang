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
	BubbleStyleID   string
}

type RoomMember struct {
	MemberID        string
	AccountID       string
	ProfileID       string
	PlayerName      string
	TeamID          int
	SlotIndex       int
	MemberPhase     string
	ConnectionState string
	ConnectionID    string
	ReconnectToken  string
	Ready           bool
	Loadout         RoomLoadout
}

type RoomFSMState struct {
	Phase      string
	LastReason string
	Revision   int64
	StatusText string
}

type QueueFSMProjection struct {
	Phase          string
	TerminalReason string
	QueueEntryID   string
	StatusText     string
	ErrorCode      string
	UserMessage    string
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
	AssignmentID       string
	AssignmentRevision int
	BattleID           string
	MatchID            string
	ServerHost         string
	ServerPort         int
	Ready              bool
	AllocationState    string
}

type BattleHandoffFSMProjection struct {
	Phase              string
	TerminalReason     string
	AssignmentID       string
	AssignmentRevision int
	BattleID           string
	MatchID            string
	ServerHost         string
	ServerPort         int
	Ready              bool
	StatusText         string
}

type RoomCapabilitySet struct {
	CanToggleReady           bool
	CanStartManualBattle     bool
	CanUpdateSelection       bool
	CanUpdateMatchRoomConfig bool
	CanEnterQueue            bool
	CanCancelQueue           bool
	CanLeaveRoom             bool
}

type RoomAggregate struct {
	RoomID           string
	RoomKind         string
	RoomDisplayName  string
	SnapshotRevision int64
	Selection        RoomSelection
	Members          map[string]RoomMember
	ResumeBindings   map[string]ResumeBinding
	MaxPlayerCount   int
	OpenSlotIndices  []int

	RoomState          RoomFSMState
	QueueState         QueueFSMProjection
	BattleState        BattleHandoffFSMProjection
	Capabilities       RoomCapabilitySet
	LifecycleState     string         // legacy alias projection only
	Queue              RoomQueueState // legacy alias projection only
	BattleHandoffState BattleHandoff  // legacy alias projection only
}
