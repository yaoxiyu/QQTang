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
	RoomID           string
	RoomKind         string
	RoomDisplayName  string
	LifecycleState   string
	SnapshotRevision int64
	OwnerMemberID    string
	Selection        domain.RoomSelection
	Members          []domain.RoomMember
	QueueState       domain.RoomQueueState
	BattleHandoff    domain.BattleHandoff
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
		RoomID:           roomID,
		RoomKind:         input.RoomKind,
		RoomDisplayName:  input.RoomDisplayName,
		LifecycleState:   "idle",
		SnapshotRevision: 1,
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
			QueueType:  "",
			QueueState: "idle",
		},
		ResumeBindings: map[string]domain.ResumeBinding{
			member.MemberID: {
				MemberID:                member.MemberID,
				ReconnectToken:          reconnectToken,
				ReconnectDeadlineUnixMS: time.Now().Add(30 * time.Second).UnixMilli(),
			},
		},
		BattleHandoffState: domain.BattleHandoff{
			Ready: false,
		},
		MaxPlayerCount: mapEntry.MaxPlayerCount,
	}

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
	room.SnapshotRevision++
	s.roomByMemberID[memberID] = room.RoomID
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
	room.SnapshotRevision++
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
	room.SnapshotRevision++
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
	room.SnapshotRevision++
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
	room.SnapshotRevision++
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
	room.SnapshotRevision++
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
	room.SnapshotRevision++
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
	if !canEnterQueueFromState(room.Queue.QueueState) {
		return nil, ErrQueueStateInvalid
	}
	if !allMembersReady(room.Members) {
		return nil, ErrMembersNotReady
	}
	requiredPartySize := requiredPartySizeFromMatchFormat(room.Selection.MatchFormatID)
	if len(room.Members) != requiredPartySize {
		return nil, ErrPartySizeMismatch
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	queueType := queueTypeByRoomKind(room.RoomKind)
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
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	room.Queue.QueueType = queueType
	room.Queue.QueueState = result.QueueState
	room.Queue.QueueEntryID = result.QueueEntryID
	room.Queue.StatusText = result.StatusText
	room.Queue.ErrorCode = ""
	room.Queue.UserMessage = ""
	room.LifecycleState = "queueing"
	room.SnapshotRevision++
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
	if !canCancelQueueFromState(room.Queue.QueueState) {
		return nil, ErrQueueStateInvalid
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	result, err := s.game.CancelPartyQueue(gameclient.CancelPartyQueueInput{
		RoomID:       room.RoomID,
		RoomKind:     room.RoomKind,
		QueueType:    room.Queue.QueueType,
		QueueEntryID: room.Queue.QueueEntryID,
	})
	if err != nil {
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	room.Queue.QueueState = result.QueueState
	room.Queue.StatusText = result.StatusText
	room.Queue.ErrorCode = ""
	room.Queue.UserMessage = ""
	room.LifecycleState = "idle"
	room.SnapshotRevision++
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
	if !allMembersReady(room.Members) {
		return nil, ErrMembersNotReady
	}
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	result, err := s.game.CreateManualRoomBattle(gameclient.CreateManualRoomBattleInput{
		RoomID:    room.RoomID,
		RoomKind:  room.RoomKind,
		MapID:     room.Selection.MapID,
		ModeID:    room.Selection.ModeID,
		RuleSetID: room.Selection.RuleSetID,
		Members:   buildPartyMembers(room.Members),
	})
	if err != nil {
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("%s: %s", result.ErrorCode, result.UserMessage)
	}

	room.BattleHandoffState.AssignmentID = result.AssignmentID
	room.BattleHandoffState.MatchID = result.MatchID
	room.BattleHandoffState.BattleID = result.BattleID
	room.BattleHandoffState.ServerHost = result.ServerHost
	room.BattleHandoffState.ServerPort = result.ServerPort
	room.BattleHandoffState.AllocationState = result.AllocationState
	room.BattleHandoffState.Ready = result.Ready
	room.LifecycleState = "battle_handoff"
	room.SnapshotRevision++
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
	if s.game == nil {
		return nil, fmt.Errorf("game client not configured")
	}

	handoff := room.BattleHandoffState
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

	room.BattleHandoffState.Ready = true
	if result.CommittedState != "" {
		room.BattleHandoffState.AllocationState = result.CommittedState
	}
	room.Queue.QueueState = "matched"
	room.Queue.StatusText = "battle_entry_acknowledged"
	room.LifecycleState = "battle_entry_acknowledged"
	room.SnapshotRevision++
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
	member.Ready = !member.Ready
	room.Members[input.MemberID] = member
	room.SnapshotRevision++
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
		RoomID:           room.RoomID,
		RoomKind:         room.RoomKind,
		RoomDisplayName:  room.RoomDisplayName,
		LifecycleState:   room.LifecycleState,
		SnapshotRevision: room.SnapshotRevision,
		OwnerMemberID:    s.roomOwnerByID[room.RoomID],
		Selection:        room.Selection,
		Members:          members,
		QueueState:       room.Queue,
		BattleHandoff:    room.BattleHandoffState,
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
	return queueState == "" || queueState == "idle" || queueState == "cancelled" || queueState == "failed"
}

func canCancelQueueFromState(queueState string) bool {
	return queueState == "queueing" || queueState == "queued"
}

func shouldSyncQueueState(queueState string) bool {
	switch strings.TrimSpace(queueState) {
	case "queueing", "queued", "assigned", "committing", "allocating", "battle_ready":
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
		if room.Queue.QueueEntryID == "" {
			continue
		}
		if !shouldSyncQueueState(room.Queue.QueueState) {
			continue
		}
		targets = append(targets, queueSyncTarget{
			roomID:       room.RoomID,
			roomKind:     room.RoomKind,
			queueEntryID: room.Queue.QueueEntryID,
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
	if room.Queue.QueueEntryID != target.queueEntryID {
		return nil, false
	}
	if !shouldSyncQueueState(room.Queue.QueueState) {
		return nil, false
	}

	changed := false

	if room.Queue.QueueState != result.QueueState {
		room.Queue.QueueState = result.QueueState
		changed = true
	}
	if room.Queue.StatusText != result.QueueState {
		room.Queue.StatusText = result.QueueState
		changed = true
	}
	if room.Queue.ErrorCode != result.ErrorCode {
		room.Queue.ErrorCode = result.ErrorCode
		changed = true
	}
	if room.Queue.UserMessage != result.UserMessage {
		room.Queue.UserMessage = result.UserMessage
		changed = true
	}

	if room.BattleHandoffState.AssignmentID != result.AssignmentID {
		room.BattleHandoffState.AssignmentID = result.AssignmentID
		changed = true
	}
	if room.BattleHandoffState.MatchID != result.MatchID {
		room.BattleHandoffState.MatchID = result.MatchID
		changed = true
	}
	if room.BattleHandoffState.BattleID != result.BattleID {
		room.BattleHandoffState.BattleID = result.BattleID
		changed = true
	}
	if room.BattleHandoffState.ServerHost != result.ServerHost {
		room.BattleHandoffState.ServerHost = result.ServerHost
		changed = true
	}
	if room.BattleHandoffState.ServerPort != result.ServerPort {
		room.BattleHandoffState.ServerPort = result.ServerPort
		changed = true
	}
	if room.BattleHandoffState.AllocationState != result.QueueState {
		room.BattleHandoffState.AllocationState = result.QueueState
		changed = true
	}
	ready := isBattleEntryReadyStatus(result)
	if room.BattleHandoffState.Ready != ready {
		room.BattleHandoffState.Ready = ready
		changed = true
	}

	nextLifecycleState := room.LifecycleState
	switch {
	case ready:
		nextLifecycleState = "battle_handoff"
	case strings.TrimSpace(result.QueueState) == "queueing" || strings.TrimSpace(result.QueueState) == "queued":
		nextLifecycleState = "queueing"
	case strings.TrimSpace(result.QueueState) == "assigned" || strings.TrimSpace(result.QueueState) == "committing" || strings.TrimSpace(result.QueueState) == "allocating":
		nextLifecycleState = "queueing"
	case strings.TrimSpace(result.QueueState) == "cancelled" || strings.TrimSpace(result.QueueState) == "failed":
		nextLifecycleState = "idle"
	}

	if room.LifecycleState != nextLifecycleState {
		room.LifecycleState = nextLifecycleState
		changed = true
	}

	if !changed {
		return nil, false
	}

	room.SnapshotRevision++
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), true
}

func allMembersReady(members map[string]domain.RoomMember) bool {
	if len(members) == 0 {
		return false
	}
	for _, member := range members {
		if !member.Ready {
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
	if strings.TrimSpace(result.AssignmentID) == "" || strings.TrimSpace(result.BattleID) == "" {
		return false
	}
	return strings.TrimSpace(result.ServerHost) != "" && result.ServerPort > 0
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
		!canCancelQueueFromState(room.Queue.QueueState) &&
		room.Queue.QueueState != "matched" &&
		room.LifecycleState != "battle_handoff" &&
		room.LifecycleState != "battle_entry_acknowledged"
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
