package roomapp

import (
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/gameclient"
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
	Loadout    Loadout
}

type UpdateSelectionInput struct {
	RoomID    string
	MemberID  string
	Selection Selection
}

type ToggleReadyInput struct {
	RoomID   string
	MemberID string
}

type SnapshotProjection struct {
	RoomID           string
	RoomKind         string
	RoomDisplayName  string
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
	resolvedLoadout, err := s.validateLoadout(input.Loadout)
	if err != nil {
		return nil, err
	}
	resolvedSelection, mapEntry, err := s.validateSelection(input.RoomKind, input.Selection, 1)
	if err != nil {
		return nil, err
	}
	if input.RoomKind == "" {
		input.RoomKind = "private_room"
	}

	roomID := s.nextID("room")
	memberID := s.nextID("member")
	reconnectToken := s.nextID("reconnect")
	member := domain.RoomMember{
		MemberID:       memberID,
		AccountID:      input.AccountID,
		ProfileID:      input.ProfileID,
		PlayerName:     input.PlayerName,
		ConnectionID:   input.ConnectionID,
		ReconnectToken: reconnectToken,
		Ready:          false,
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
		SnapshotRevision: 1,
		Selection: domain.RoomSelection{
			MapID:         resolvedSelection.MapID,
			RuleSetID:     resolvedSelection.RuleSetID,
			ModeID:        resolvedSelection.ModeID,
			MatchFormatID: resolvedSelection.MatchFormatID,
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
		MemberID:       memberID,
		AccountID:      input.AccountID,
		ProfileID:      input.ProfileID,
		PlayerName:     input.PlayerName,
		ConnectionID:   input.ConnectionID,
		ReconnectToken: reconnectToken,
		Ready:          false,
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
	room.Members[input.MemberID] = member
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
		delete(s.roomsByID, input.RoomID)
		delete(s.roomOwnerByID, input.RoomID)
		return nil, nil
	}
	room.SnapshotRevision++
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
		MapID:         resolvedSelection.MapID,
		RuleSetID:     resolvedSelection.RuleSetID,
		ModeID:        resolvedSelection.ModeID,
		MatchFormatID: resolvedSelection.MatchFormatID,
	}
	room.MaxPlayerCount = mapEntry.MaxPlayerCount
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

	if roomKind == "casual_match_room" || roomKind == "ranked_match_room" || roomKind == "matchmade_room" {
		if len(resolved.SelectedModeIDs) == 0 && resolved.ModeID != "" {
			resolved.SelectedModeIDs = []string{resolved.ModeID}
		}
		if _, err := s.query.ValidateMatchRoomConfig(resolved.MatchFormatID, resolved.SelectedModeIDs); err != nil {
			return Selection{}, nil, ErrInvalidSelection
		}
		queueType := "casual"
		if roomKind == "ranked_match_room" {
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
	} else {
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
		members = append(members, member)
	}
	return &SnapshotProjection{
		RoomID:           room.RoomID,
		RoomKind:         room.RoomKind,
		RoomDisplayName:  room.RoomDisplayName,
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
