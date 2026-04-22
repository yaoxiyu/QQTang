package roomapp

import (
	"errors"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/gameclient"
	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/registry"
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
	CharacterID     string
	CharacterSkinID string
	BubbleStyleID   string
	BubbleSkinID    string
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
	RoomID    string
	MemberID  string
	Selection Selection
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

type Service struct {
	registry *registry.Registry
	manifest *manifest.Loader
	query    *manifest.Query
	verifier *auth.TicketVerifier
	game     *gameclient.Client

	mu             sync.RWMutex
	roomsByID      map[string]*domain.RoomAggregate
	roomByMemberID map[string]string
	roomOwnerByID  map[string]string
	idCounter      atomic.Int64
}

var roomTransitionEngine = RoomTransitionEngine{}

func NewService(reg *registry.Registry, man *manifest.Loader, verifier *auth.TicketVerifier, game *gameclient.Client) *Service {
	return &Service{
		registry:       reg,
		manifest:       man,
		query:          manifest.NewQuery(man),
		verifier:       verifier,
		game:           game,
		roomsByID:      map[string]*domain.RoomAggregate{},
		roomByMemberID: map[string]string{},
		roomOwnerByID:  map[string]string{},
	}
}

func (s *Service) Ready() bool {
	return s != nil &&
		s.registry != nil &&
		s.registry.Ready() &&
		s.manifest != nil &&
		s.manifest.Ready() &&
		s.verifier != nil
}

func (s *Service) CreateRoom(input CreateRoomInput) (*SnapshotProjection, error) {
	if !s.Ready() {
		return nil, fmt.Errorf("room app not ready")
	}
	if !s.verifier.Verify(input.RoomTicket) {
		return nil, ErrInvalidTicket
	}
	normalizedRoomKind, err := normalizeRoomKind(input.RoomKind)
	if err != nil {
		return nil, err
	}
	input.RoomKind = normalizedRoomKind

	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	resolvedSelection, mapEntry, err := s.validateSelection(input.RoomKind, input.Selection, 1)
	if err != nil {
		return nil, err
	}

	roomID := s.nextID("room")
	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	member := domain.RoomMember{
		MemberID:        memberID,
		AccountID:       input.AccountID,
		ProfileID:       input.ProfileID,
		PlayerName:      input.PlayerName,
		TeamID:          1,
		MemberPhase:     MemberPhaseIdle,
		ConnectionState: "connected",
		ConnectionID:    input.ConnectionID,
		ReconnectToken:  reconnectToken,
		Ready:           false,
		Loadout: domain.RoomLoadout{
			CharacterID:     resolvedLoadout.CharacterID,
			CharacterSkinID: resolvedLoadout.CharacterSkinID,
			BubbleStyleID:   resolvedLoadout.BubbleStyleID,
			BubbleSkinID:    resolvedLoadout.BubbleSkinID,
		},
	}

	agg := &domain.RoomAggregate{
		RoomID:          roomID,
		RoomKind:        input.RoomKind,
		RoomDisplayName: input.RoomDisplayName,
		Selection: domain.RoomSelection{
			MapID:           resolvedSelection.MapID,
			RuleSetID:       resolvedSelection.RuleSetID,
			ModeID:          resolvedSelection.ModeID,
			MatchFormatID:   resolvedSelection.MatchFormatID,
			SelectedModeIDs: append([]string{}, resolvedSelection.SelectedModeIDs...),
		},
		Members: map[string]domain.RoomMember{
			member.MemberID: member,
		},
		Queue: domain.RoomQueueState{
			QueueType: "",
		},
		ResumeBindings: map[string]domain.ResumeBinding{
			member.MemberID: {
				MemberID:                member.MemberID,
				ReconnectToken:          reconnectToken,
				ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
			},
		},
		RoomState: domain.RoomFSMState{
			Phase:      RoomPhaseIdle,
			LastReason: RoomReasonNone,
		},
		QueueState: domain.QueueFSMProjection{
			Phase:          QueuePhaseIdle,
			TerminalReason: QueueReasonNone,
		},
		BattleState: domain.BattleHandoffFSMProjection{
			Phase:          BattlePhaseIdle,
			TerminalReason: BattleReasonNone,
		},
		MaxPlayerCount: mapEntry.MaxPlayerCount,
	}
	roomTransitionEngine.ApplyCreateRoom(agg, memberID)

	s.mu.Lock()
	s.roomsByID[roomID] = agg
	s.roomByMemberID[memberID] = roomID
	s.roomOwnerByID[roomID] = memberID
	s.syncDirectoryEntryLocked(agg)
	s.mu.Unlock()

	return s.snapshotProjectionLocked(agg), nil
}

func (s *Service) JoinRoom(input JoinRoomInput) (*SnapshotProjection, error) {
	if !s.verifier.Verify(input.RoomTicket) {
		return nil, ErrInvalidTicket
	}
	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if len(room.Members) >= room.MaxPlayerCount {
		return nil, ErrRoomNotJoinable
	}

	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	room.Members[memberID] = domain.RoomMember{
		MemberID:        memberID,
		AccountID:       input.AccountID,
		ProfileID:       input.ProfileID,
		PlayerName:      input.PlayerName,
		TeamID:          1,
		MemberPhase:     MemberPhaseIdle,
		ConnectionState: "connected",
		ConnectionID:    input.ConnectionID,
		ReconnectToken:  reconnectToken,
		Ready:           false,
		Loadout: domain.RoomLoadout{
			CharacterID:     resolvedLoadout.CharacterID,
			CharacterSkinID: resolvedLoadout.CharacterSkinID,
			BubbleStyleID:   resolvedLoadout.BubbleStyleID,
			BubbleSkinID:    resolvedLoadout.BubbleSkinID,
		},
	}
	room.ResumeBindings[memberID] = domain.ResumeBinding{
		MemberID:                memberID,
		ReconnectToken:          reconnectToken,
		ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
	}
	s.roomByMemberID[memberID] = room.RoomID
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) ResumeRoom(input ResumeRoomInput) (*SnapshotProjection, error) {
	if !s.verifier.Verify(input.RoomTicket) {
		return nil, ErrInvalidTicket
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	binding := room.ResumeBindings[input.MemberID]
	if binding.ReconnectToken != input.ReconnectToken {
		return nil, ErrReconnectForbidden
	}
	member.ConnectionID = input.ConnectionID
	member.ConnectionState = "connected"
	room.Members[input.MemberID] = member
	restoreMemberPhase(room, input.MemberID)
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) MarkDisconnected(roomID string, memberID string) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[memberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	member.ConnectionState = "disconnected"
	member.ConnectionID = ""
	room.Members[memberID] = member
	markMemberDisconnected(room, memberID)
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) LeaveRoom(input LeaveRoomInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	delete(room.Members, input.MemberID)
	delete(room.ResumeBindings, input.MemberID)
	delete(s.roomByMemberID, input.MemberID)

	if len(room.Members) == 0 {
		s.registry.RemoveRoomEntry(input.RoomID)
		delete(s.roomsByID, input.RoomID)
		delete(s.roomOwnerByID, input.RoomID)
		return nil, nil
	}
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateProfile(input UpdateProfileInput) (*SnapshotProjection, error) {
	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	if input.PlayerName != "" {
		member.PlayerName = input.PlayerName
	}
	if input.TeamID > 0 {
		member.TeamID = input.TeamID
	}
	member.Loadout = domain.RoomLoadout{
		CharacterID:     resolvedLoadout.CharacterID,
		CharacterSkinID: resolvedLoadout.CharacterSkinID,
		BubbleStyleID:   resolvedLoadout.BubbleStyleID,
		BubbleSkinID:    resolvedLoadout.BubbleSkinID,
	}
	room.Members[input.MemberID] = member
	s.touchRoomSnapshotLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateSelection(input UpdateSelectionInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isManualRoomKind(room.RoomKind) {
		return nil, ErrManualRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	roomKind := room.RoomKind
	if roomKind == "" {
		roomKind = "private_room"
	}
	resolvedSelection, mapEntry, err := s.validateSelection(roomKind, input.Selection, len(room.Members))
	if err != nil {
		return nil, err
	}
	room.Selection = domain.RoomSelection{
		MapID:           resolvedSelection.MapID,
		RuleSetID:       resolvedSelection.RuleSetID,
		ModeID:          resolvedSelection.ModeID,
		MatchFormatID:   resolvedSelection.MatchFormatID,
		SelectedModeIDs: append([]string{}, resolvedSelection.SelectedModeIDs...),
	}
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) UpdateMatchRoomConfig(input UpdateMatchRoomConfigInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}

	selectedModeIDs := append([]string{}, input.SelectedModeIDs...)
	if len(selectedModeIDs) == 0 && room.Selection.ModeID != "" {
		selectedModeIDs = []string{room.Selection.ModeID}
	}
	if _, err := s.query.ValidateMatchRoomConfig(input.MatchFormatID, selectedModeIDs); err != nil {
		return nil, ErrInvalidSelection
	}

	queueType := "casual"
	if room.RoomKind == "ranked_match_room" {
		queueType = "ranked"
	}
	mapPool, err := s.query.ResolveMapPool(input.MatchFormatID, selectedModeIDs, queueType)
	if err != nil || len(mapPool) == 0 {
		return nil, ErrInvalidSelection
	}
	mapEntry := mapPool[0]

	room.Selection.MatchFormatID = input.MatchFormatID
	room.Selection.SelectedModeIDs = selectedModeIDs
	room.Selection.MapID = mapEntry.MapID
	room.Selection.ModeID = mapEntry.ModeID
	room.Selection.RuleSetID = mapEntry.RuleSetID
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
	s.touchRoomSnapshotLocked(room)
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) EnterMatchQueue(input EnterMatchQueueInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	if !allMembersReady(room.Members) {
		return nil, ErrMembersNotReady
	}
	requiredPartySize := requiredPartySizeFromMatchFormat(room.Selection.MatchFormatID)
	if len(room.Members) != requiredPartySize {
		return nil, ErrPartySizeMismatch
	}
	selectedModeIDs := append([]string{}, room.Selection.SelectedModeIDs...)
	if len(selectedModeIDs) == 0 && room.Selection.ModeID != "" {
		selectedModeIDs = []string{room.Selection.ModeID}
	}
	if _, err := s.query.ValidateMatchRoomConfig(room.Selection.MatchFormatID, selectedModeIDs); err != nil {
		return nil, ErrInvalidSelection
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	queueType := queueTypeByRoomKind(room.RoomKind)
	roomTransitionEngine.ApplyQueueEnterRequested(room, s.roomOwnerByID[input.RoomID])
	gameInput := gameclient.EnterPartyQueueInput{
		RoomID:          room.RoomID,
		RoomKind:        room.RoomKind,
		QueueType:       queueType,
		MatchFormatID:   room.Selection.MatchFormatID,
		SelectedModeIDs: append([]string{}, room.Selection.SelectedModeIDs...),
		Members:         buildPartyMembers(room.Members),
	}
	result, err := s.game.EnterPartyQueue(gameInput)
	if err != nil {
		roomTransitionEngine.ApplyQueueEnterFailed(room, s.roomOwnerByID[input.RoomID], "ENTER_QUEUE_RPC_ERROR", err.Error())
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyQueueEnterFailed(room, s.roomOwnerByID[input.RoomID], result.ErrorCode, result.UserMessage)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	room.Queue.QueueType = queueType
	queuePhase, terminalReason := resolveQueuePhaseAndTerminalReason(
		result.QueuePhase,
		result.QueueTerminalReason,
		result.QueueState,
		result.OK,
	)
	statusText := resolveQueueStatusText(result.QueueStatusText, result.StatusText, result.QueueState)
	roomTransitionEngine.ApplyQueueAccepted(
		room,
		s.roomOwnerByID[input.RoomID],
		queuePhase,
		terminalReason,
		statusText,
		result.QueueEntryID,
		"",
		"",
	)
	room.Queue.QueueType = queueType
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) CancelMatchQueue(input CancelMatchQueueInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isMatchRoomKind(room.RoomKind) {
		return nil, ErrMatchRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	switch room.RoomState.Phase {
	case RoomPhaseQueueActive, RoomPhaseBattleAllocating, RoomPhaseBattleEntryReady:
	default:
		return nil, ErrRoomPhaseInvalid
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}
	previousRoomPhase := room.RoomState.Phase
	roomTransitionEngine.ApplyQueueCancelRequested(room, s.roomOwnerByID[input.RoomID])

	result, err := s.game.CancelPartyQueue(gameclient.CancelPartyQueueInput{
		RoomID:       room.RoomID,
		RoomKind:     room.RoomKind,
		QueueType:    room.Queue.QueueType,
		QueueEntryID: room.Queue.QueueEntryID,
	})
	if err != nil {
		roomTransitionEngine.ApplyQueueCancelFailed(room, s.roomOwnerByID[input.RoomID], previousRoomPhase)
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyQueueCancelFailed(room, s.roomOwnerByID[input.RoomID], previousRoomPhase)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}
	roomTransitionEngine.ApplyQueueCancelled(room, s.roomOwnerByID[input.RoomID])
	return s.snapshotProjectionLocked(room), nil
}

type QueueStatusSyncResult struct {
	RoomID   string
	Snapshot *SnapshotProjection
}

func (s *Service) SyncMatchQueueStatus() []QueueStatusSyncResult {
	if s == nil || s.game == nil {
		return nil
	}

	targets := s.collectQueueSyncTargets()
	if len(targets) == 0 {
		return nil
	}

	updates := make([]QueueStatusSyncResult, 0, len(targets))
	for _, target := range targets {
		result, err := s.game.GetPartyQueueStatus(gameclient.GetPartyQueueStatusInput{
			RoomID:       target.roomID,
			RoomKind:     target.roomKind,
			QueueEntryID: target.queueEntryID,
		})
		if err != nil {
			continue
		}
		snapshot, changed := s.applyQueueStatusResult(target, result)
		if changed && snapshot != nil {
			updates = append(updates, QueueStatusSyncResult{
				RoomID:   target.roomID,
				Snapshot: snapshot,
			})
		}
	}
	return updates
}

func (s *Service) StartManualRoomBattle(input StartManualRoomBattleInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if !isManualRoomKind(room.RoomKind) {
		return nil, ErrManualRoomOnly
	}
	if ownerID := s.roomOwnerByID[input.RoomID]; ownerID != input.MemberID {
		return nil, ErrNotRoomOwner
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	if !allMembersReady(room.Members) {
		return nil, ErrMembersNotReady
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}
	roomTransitionEngine.ApplyManualBattleRequested(room, s.roomOwnerByID[input.RoomID])

	result, err := s.game.CreateManualRoomBattle(gameclient.CreateManualRoomBattleInput{
		RoomID:    room.RoomID,
		RoomKind:  room.RoomKind,
		MapID:     room.Selection.MapID,
		ModeID:    room.Selection.ModeID,
		RuleSetID: room.Selection.RuleSetID,
		Members:   buildPartyMembers(room.Members),
	})
	if err != nil {
		roomTransitionEngine.ApplyManualBattleAllocationFailed(room, s.roomOwnerByID[input.RoomID], "MANUAL_BATTLE_ALLOCATE_RPC_ERROR", err.Error())
		return nil, err
	}
	if !result.OK {
		roomTransitionEngine.ApplyManualBattleAllocationFailed(room, s.roomOwnerByID[input.RoomID], result.ErrorCode, result.UserMessage)
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	roomTransitionEngine.ApplyBattleHandoffUpdated(room, s.roomOwnerByID[input.RoomID], BattleHandoffUpdate{
		AssignmentID:   result.AssignmentID,
		MatchID:        result.MatchID,
		BattleID:       result.BattleID,
		ServerHost:     result.ServerHost,
		ServerPort:     result.ServerPort,
		Phase:          BattlePhaseReady,
		TerminalReason: BattleReasonManualStart,
		Ready:          true,
	})
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) AckBattleEntry(input AckBattleEntryInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	if _, ok := room.Members[input.MemberID]; !ok {
		return nil, ErrMemberNotFound
	}
	if room.RoomState.Phase != RoomPhaseBattleEntryReady || room.BattleState.Phase != BattlePhaseReady {
		return nil, ErrRoomPhaseInvalid
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	handoff := room.BattleState
	if handoff.AssignmentID == "" || handoff.AssignmentID != input.AssignmentID {
		return nil, fmt.Errorf("assignment mismatch")
	}
	if handoff.BattleID != "" && input.BattleID != "" && handoff.BattleID != input.BattleID {
		return nil, fmt.Errorf("battle mismatch")
	}
	if handoff.MatchID != "" && input.MatchID != "" && handoff.MatchID != input.MatchID {
		return nil, fmt.Errorf("match mismatch")
	}

	result, err := s.game.CommitAssignmentReady(gameclient.CommitAssignmentReadyInput{
		RoomID:       room.RoomID,
		RoomKind:     room.RoomKind,
		AssignmentID: input.AssignmentID,
		BattleID:     input.BattleID,
		MatchID:      input.MatchID,
	})
	if err != nil {
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	roomTransitionEngine.ApplyBattleEntryAckRequested(room, s.roomOwnerByID[input.RoomID])
	room.QueueState.StatusText = "battle_entry_acknowledged"
	roomTransitionEngine.ApplyBattleEntryAcked(room, s.roomOwnerByID[input.RoomID])
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) ToggleReady(input ToggleReadyInput) (*SnapshotProjection, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	room := s.roomsByID[input.RoomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	member, ok := room.Members[input.MemberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	if room.RoomState.Phase != RoomPhaseIdle {
		return nil, ErrRoomPhaseInvalid
	}
	if member.MemberPhase != MemberPhaseIdle && member.MemberPhase != MemberPhaseReady {
		return nil, ErrMemberPhaseInvalid
	}
	if !toggleMemberReady(room, input.MemberID) {
		return nil, ErrMemberPhaseInvalid
	}
	roomTransitionEngine.ApplyToggleReady(room, s.roomOwnerByID[input.RoomID])
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) SnapshotProjection(roomID string) (*SnapshotProjection, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return nil, ErrRoomNotFound
	}
	return s.snapshotProjectionLocked(room), nil
}

func (s *Service) ReconnectToken(roomID, memberID string) (string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	room := s.roomsByID[roomID]
	if room == nil {
		return "", ErrRoomNotFound
	}
	binding, ok := room.ResumeBindings[memberID]
	if !ok {
		return "", ErrMemberNotFound
	}
	return binding.ReconnectToken, nil
}

func (s *Service) ResolveRoomMemberByConnection(connectionID string) (string, string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for roomID, room := range s.roomsByID {
		for memberID, member := range room.Members {
			if member.ConnectionID == connectionID {
				return roomID, memberID, nil
			}
		}
	}
	return "", "", ErrMemberNotFound
}

func (s *Service) SetDirectorySubscribed(connectionID string, subscribed bool) {
	if s == nil || s.registry == nil {
		return
	}
	s.registry.SetDirectorySubscribed(connectionID, subscribed)
}

func (s *Service) DirectorySubscriberIDs() []string {
	if s == nil || s.registry == nil {
		return nil
	}
	return s.registry.DirectorySubscriberIDs()
}

func (s *Service) DirectorySnapshot(serverHost string, serverPort int32) *roomv1.RoomDirectorySnapshot {
	result := &roomv1.RoomDirectorySnapshot{
		ServerHost: serverHost,
		ServerPort: serverPort,
	}
	if s == nil || s.registry == nil {
		return result
	}
	snapshot := s.registry.DirectorySnapshot()
	result.Revision = snapshot.Revision
	result.Entries = make([]*roomv1.RoomDirectoryEntry, 0, len(snapshot.Entries))
	for _, entry := range snapshot.Entries {
		result.Entries = append(result.Entries, &roomv1.RoomDirectoryEntry{
			RoomId:          entry.RoomID,
			RoomDisplayName: entry.RoomDisplayName,
			RoomKind:        entry.RoomKind,
			ModeId:          entry.ModeID,
			MapId:           entry.MapID,
			MemberCount:     entry.MemberCount,
			MaxPlayerCount:  entry.MaxPlayerCount,
			Joinable:        entry.Joinable,
		})
	}
	return result
}

func (s *Service) validateLoadout(loadout Loadout) (Loadout, error) {
	resolved := loadout
	if resolved.CharacterID == "" {
		resolved.CharacterID = s.manifest.Manifest().Assets.DefaultCharacterID
	}
	if !s.manifest.HasLegalCharacterID(resolved.CharacterID) {
		return Loadout{}, ErrInvalidLoadout
	}
	if !s.manifest.HasLegalCharacterSkinID(resolved.CharacterSkinID) {
		return Loadout{}, ErrInvalidLoadout
	}
	if resolved.BubbleStyleID == "" {
		resolved.BubbleStyleID = s.manifest.Manifest().Assets.DefaultBubbleStyleID
	}
	if !s.manifest.HasLegalBubbleStyleID(resolved.BubbleStyleID) {
		return Loadout{}, ErrInvalidLoadout
	}
	if !s.manifest.HasLegalBubbleSkinID(resolved.BubbleSkinID) {
		return Loadout{}, ErrInvalidLoadout
	}
	return resolved, nil
}

func (s *Service) validateSelection(roomKind string, selection Selection, memberCount int) (Selection, *manifest.MapEntry, error) {
	resolved := selection
	if resolved.MapID == "" {
		first := s.manifest.FirstMap()
		if first == nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		resolved.MapID = first.MapID
	}
	mapEntry := s.manifest.FindMap(resolved.MapID)
	if mapEntry == nil {
		return Selection{}, nil, ErrInvalidSelection
	}
	if resolved.ModeID == "" {
		resolved.ModeID = mapEntry.ModeID
	}
	if resolved.RuleSetID == "" {
		resolved.RuleSetID = mapEntry.RuleSetID
	}
	if resolved.MatchFormatID == "" && len(mapEntry.MatchFormatIDs) > 0 {
		resolved.MatchFormatID = mapEntry.MatchFormatIDs[0]
	}

	switch domain.ParseRoomKindCategory(roomKind) {
	case domain.RoomKindMatch, domain.RoomKindRanked:
		if strings.TrimSpace(resolved.MatchFormatID) == "" {
			resolved.MatchFormatID = "1v1"
		}
		if len(resolved.SelectedModeIDs) == 0 && resolved.ModeID != "" {
			resolved.SelectedModeIDs = []string{resolved.ModeID}
		}
		if _, err := s.query.ValidateMatchRoomConfig(resolved.MatchFormatID, resolved.SelectedModeIDs); err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		queueType := "casual"
		if domain.ParseRoomKindCategory(roomKind) == domain.RoomKindRanked {
			queueType = "ranked"
		}
		mapPool, err := s.query.ResolveMapPool(resolved.MatchFormatID, resolved.SelectedModeIDs, queueType)
		if err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		mapEntry = &mapPool[0]
		resolved.MapID = mapEntry.MapID
		resolved.ModeID = mapEntry.ModeID
		resolved.RuleSetID = mapEntry.RuleSetID
	default:
		validated, err := s.query.ValidateCustomRoomSelection(resolved.MapID, resolved.ModeID, resolved.RuleSetID)
		if err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		mapEntry = validated
	}

	if err := s.query.ValidateTeamAndPlayerCount(mapEntry.MapID, mapEntry.RequiredTeamCount, memberCount); err != nil {
		return Selection{}, nil, ErrInvalidSelection
	}
	return resolved, mapEntry, nil
}

func (s *Service) snapshotProjectionLocked(room *domain.RoomAggregate) *SnapshotProjection {
	if room == nil {
		return nil
	}
	members := make([]domain.RoomMember, 0, len(room.Members))
	for _, member := range room.Members {
		member.ReconnectToken = ""
		members = append(members, member)
	}
	return &SnapshotProjection{
		RoomID:               room.RoomID,
		RoomKind:             room.RoomKind,
		RoomDisplayName:      room.RoomDisplayName,
		LifecycleState:       room.LifecycleState,
		RoomPhase:            room.RoomState.Phase,
		RoomPhaseReason:      room.RoomState.LastReason,
		SnapshotRevision:     room.SnapshotRevision,
		OwnerMemberID:        s.roomOwnerByID[room.RoomID],
		Selection:            room.Selection,
		Members:              members,
		QueuePhase:           room.QueueState.Phase,
		QueueTerminalReason:  room.QueueState.TerminalReason,
		QueueStatusText:      room.QueueState.StatusText,
		QueueErrorCode:       room.QueueState.ErrorCode,
		QueueUserMessage:     room.QueueState.UserMessage,
		QueueEntryID:         room.QueueState.QueueEntryID,
		BattlePhase:          room.BattleState.Phase,
		BattleTerminalReason: room.BattleState.TerminalReason,
		BattleStatusText:     room.BattleState.StatusText,
		Capabilities:         room.Capabilities,
		QueueState:           room.Queue,
		BattleHandoff:        room.BattleHandoffState,
	}
}

func (s *Service) nextID(prefix string) string {
	value := s.idCounter.Add(1)
	return fmt.Sprintf("%s-%d-%d", prefix, time.Now().UnixNano(), value)
}

func isMatchRoomKind(roomKind string) bool {
	kind := domain.ParseRoomKindCategory(roomKind)
	return kind == domain.RoomKindMatch || kind == domain.RoomKindRanked
}

func isManualRoomKind(roomKind string) bool {
	return domain.ParseRoomKindCategory(roomKind) == domain.RoomKindCustom
}

func isDirectoryVisibleRoomKind(roomKind string) bool {
	return roomKind != "" && roomKind != "private_room"
}

func queueTypeByRoomKind(roomKind string) string {
	if domain.ParseRoomKindCategory(roomKind) == domain.RoomKindRanked {
		return "ranked"
	}
	return "casual"
}

func normalizeRoomKind(roomKind string) (string, error) {
	switch strings.TrimSpace(roomKind) {
	case "private_room":
		return "private_room", nil
	case "public_room":
		return "public_room", nil
	}

	switch domain.ParseRoomKindCategory(roomKind) {
	case domain.RoomKindCustom:
		return "custom_room", nil
	case domain.RoomKindMatch:
		return "casual_match_room", nil
	case domain.RoomKindRanked:
		return "ranked_match_room", nil
	default:
		if strings.TrimSpace(roomKind) == "" {
			return "custom_room", nil
		}
		return "", ErrInvalidRoomKind
	}
}

func canEnterQueueFromState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case "", QueuePhaseIdle:
		return true
	default:
		return false
	}
}

func canCancelQueueFromState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case QueuePhaseQueued, QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle, QueuePhaseEntryReady:
		return true
	default:
		return false
	}
}

func shouldSyncQueueState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case QueuePhaseQueued, QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle, QueuePhaseEntryReady:
		return true
	default:
		return false
	}
}

type queueSyncTarget struct {
	roomID       string
	roomKind     string
	queueEntryID string
}

func (s *Service) collectQueueSyncTargets() []queueSyncTarget {
	s.mu.RLock()
	defer s.mu.RUnlock()

	targets := make([]queueSyncTarget, 0)
	for _, room := range s.roomsByID {
		if room == nil {
			continue
		}
		if !isMatchRoomKind(room.RoomKind) {
			continue
		}
		if room.QueueState.QueueEntryID == "" {
			continue
		}
		if !shouldSyncQueueState(room.QueueState.Phase) {
			continue
		}
		targets = append(targets, queueSyncTarget{
			roomID:       room.RoomID,
			roomKind:     room.RoomKind,
			queueEntryID: room.QueueState.QueueEntryID,
		})
	}
	return targets
}

func (s *Service) applyQueueStatusResult(target queueSyncTarget, result gameclient.GetPartyQueueStatusResult) (*SnapshotProjection, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[target.roomID]
	if room == nil {
		return nil, false
	}
	if room.QueueState.QueueEntryID != target.queueEntryID {
		return nil, false
	}
	if !shouldSyncQueueState(room.QueueState.Phase) {
		return nil, false
	}

	changed := applyPartyQueueProjection(room, result, s.roomOwnerByID[target.roomID])
	if !changed {
		return nil, false
	}

	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), true
}

func allMembersReady(members map[string]domain.RoomMember) bool {
	if len(members) == 0 {
		return false
	}
	for _, member := range members {
		if member.MemberPhase != MemberPhaseReady {
			return false
		}
	}
	return true
}

func buildPartyMembers(members map[string]domain.RoomMember) []gameclient.PartyMember {
	result := make([]gameclient.PartyMember, 0, len(members))
	for _, member := range members {
		result = append(result, gameclient.PartyMember{
			AccountID: member.AccountID,
			ProfileID: member.ProfileID,
			TeamID:    member.TeamID,
		})
	}
	return result
}

func requiredPartySizeFromMatchFormat(matchFormatID string) int {
	switch strings.TrimSpace(matchFormatID) {
	case "2v2":
		return 2
	case "4v4":
		return 4
	case "1v1":
		return 1
	default:
		return 1
	}
}

func isBattleEntryReadyStatus(result gameclient.GetPartyQueueStatusResult) bool {
	if result.BattleEntryReady {
		return true
	}
	if strings.TrimSpace(result.AssignmentID) == "" || strings.TrimSpace(result.BattleID) == "" {
		return false
	}
	return strings.TrimSpace(result.ServerHost) != "" && result.ServerPort > 0
}

func clearBattleStateProjection(handoff *domain.BattleHandoffFSMProjection) bool {
	if handoff == nil {
		return false
	}
	changed := false
	if handoff.AssignmentID != "" {
		handoff.AssignmentID = ""
		changed = true
	}
	if handoff.MatchID != "" {
		handoff.MatchID = ""
		changed = true
	}
	if handoff.BattleID != "" {
		handoff.BattleID = ""
		changed = true
	}
	if handoff.ServerHost != "" {
		handoff.ServerHost = ""
		changed = true
	}
	if handoff.ServerPort != 0 {
		handoff.ServerPort = 0
		changed = true
	}
	if handoff.Ready {
		handoff.Ready = false
		changed = true
	}
	if handoff.Phase != BattlePhaseCompleted {
		handoff.Phase = BattlePhaseCompleted
		changed = true
	}
	if handoff.TerminalReason == "" {
		handoff.TerminalReason = BattleReasonNone
		changed = true
	}
	return changed
}

func (s *Service) syncDirectoryEntryLocked(room *domain.RoomAggregate) {
	if s == nil || s.registry == nil || room == nil {
		return
	}
	if !isDirectoryVisibleRoomKind(room.RoomKind) {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	memberCount := len(room.Members)
	joinable := memberCount < room.MaxPlayerCount &&
		!canCancelQueueFromState(room.QueueState.Phase) &&
		room.RoomState.Phase != RoomPhaseBattleEntryReady &&
		room.RoomState.Phase != RoomPhaseBattleEntering &&
		room.RoomState.Phase != RoomPhaseInBattle
	s.registry.UpsertRoomEntry(registry.DirectoryEntry{
		RoomID:          room.RoomID,
		RoomDisplayName: room.RoomDisplayName,
		RoomKind:        room.RoomKind,
		ModeID:          room.Selection.ModeID,
		MapID:           room.Selection.MapID,
		MemberCount:     int32(memberCount),
		MaxPlayerCount:  int32(room.MaxPlayerCount),
		Joinable:        joinable,
	})
}

func (s *Service) touchRoomSnapshotLocked(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	room.SnapshotRevision++
	room.RoomState.Revision = room.SnapshotRevision
	syncLegacyAliases(room)
	rebuildRoomCapabilities(room, s.roomOwnerByID[room.RoomID])
}

func legacyQueueStateToCanonical(legacy string) (string, string) {
	switch strings.TrimSpace(legacy) {
	case "queueing":
		return QueuePhaseQueued, queueReasonLegacyQueueingAlias
	case "queued":
		return QueuePhaseQueued, QueueReasonNone
	case "assigned", "committing":
		return QueuePhaseAssignmentPending, QueueReasonNone
	case "allocating":
		return QueuePhaseAllocatingBattle, QueueReasonNone
	case "battle_ready", "matched":
		return QueuePhaseEntryReady, QueueReasonNone
	case "cancelled":
		return QueuePhaseCompleted, QueueReasonClientCancelled
	case "expired":
		return QueuePhaseCompleted, QueueReasonAssignmentExpired
	case "failed":
		return QueuePhaseCompleted, QueueReasonAllocationFailed
	case "finalized":
		return QueuePhaseCompleted, QueueReasonMatchFinalized
	case "", "idle":
		return QueuePhaseIdle, QueueReasonNone
	default:
		return QueuePhaseCompleted, QueueReasonAllocationFailed
	}
}

func resolveQueuePhaseAndTerminalReason(queuePhase string, terminalReason string, legacyQueueState string, ok bool) (string, string) {
	queuePhase = strings.TrimSpace(queuePhase)
	terminalReason = strings.TrimSpace(terminalReason)
	if queuePhase == "" {
		queuePhase, terminalReason = legacyQueueStateToCanonical(legacyQueueState)
	}
	if !ok && (queuePhase == "" || queuePhase == QueuePhaseIdle) {
		queuePhase = QueuePhaseCompleted
	}
	if queuePhase == QueuePhaseCompleted && (terminalReason == "" || terminalReason == QueueReasonNone || terminalReason == queueReasonLegacyQueueingAlias) {
		_, fallbackReason := legacyQueueStateToCanonical(legacyQueueState)
		terminalReason = fallbackReason
		if terminalReason == "" || terminalReason == QueueReasonNone || terminalReason == queueReasonLegacyQueueingAlias {
			terminalReason = QueueReasonAllocationFailed
		}
	}
	if queuePhase != QueuePhaseCompleted && terminalReason == "" {
		terminalReason = QueueReasonNone
	}
	return queuePhase, terminalReason
}

func resolveQueueStatusText(queueStatusText string, fallbackStatusText string, legacyQueueState string) string {
	if value := strings.TrimSpace(queueStatusText); value != "" {
		return value
	}
	if value := strings.TrimSpace(fallbackStatusText); value != "" {
		return value
	}
	return strings.TrimSpace(legacyQueueState)
}

func nextQueuePhaseToBattlePhase(queuePhase string) string {
	switch queuePhase {
	case QueuePhaseAssignmentPending, QueuePhaseAllocatingBattle:
		return BattlePhaseAllocating
	case QueuePhaseEntryReady:
		return BattlePhaseReady
	case QueuePhaseCompleted, QueuePhaseIdle:
		return BattlePhaseCompleted
	default:
		return BattlePhaseIdle
	}
}
