package roomapp

import (
	"fmt"
	"time"
)

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

func (s *Service) nextID(prefix string) string {
	value := s.idCounter.Add(1)
	return fmt.Sprintf("%s-%d-%d", prefix, time.Now().UnixNano(), value)
}
