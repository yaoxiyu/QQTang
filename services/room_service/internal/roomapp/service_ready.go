package roomapp

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
