package roomapp

import (
	"qqtang/services/room_service/internal/domain"
	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/registry"
)

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

func (s *Service) syncDirectoryEntryLocked(room *domain.RoomAggregate) {
	if s == nil || s.registry == nil || room == nil {
		return
	}
	if !isDirectoryVisibleRoomKind(room.RoomKind) {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	if isBattleRoomEmpty(room) {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	if room.RoomState.Phase == RoomPhaseBattleEntryReady ||
		room.RoomState.Phase == RoomPhaseBattleEntering ||
		room.RoomState.Phase == RoomPhaseInBattle {
		s.registry.RemoveRoomEntry(room.RoomID)
		return
	}
	memberCount := len(room.Members)
	_, hasAvailableSlot := firstAvailableSlot(room.OpenSlotIndices, room.Members)
	joinable := hasAvailableSlot &&
		!canCancelQueueFromState(room.QueueState.Phase)
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
