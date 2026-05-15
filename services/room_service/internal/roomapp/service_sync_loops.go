package roomapp

import (
	"qqtang/services/room_service/internal/gameclient"
)

func (s *Service) SyncMatchQueueStatus() []QueueStatusSyncResult {
	if s == nil || s.game == nil {
		return nil
	}

	targets := s.collectQueueSyncTargets()
	s.metrics.queueSyncTargetCount.Add(int64(len(targets)))
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

func (s *Service) collectQueueSyncTargets() []queueSyncTarget {
	s.mu.RLock()
	defer s.mu.RUnlock()

	targets := make([]queueSyncTarget, 0)
	for _, room := range s.roomsByID {
		if room == nil {
			continue
		}
		if room.QueueState.QueueEntryID == "" {
			continue
		}
		if !isMatchRoomKind(room.RoomKind) {
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

func (s *Service) collectBattleSyncTargets() []battleSyncTarget {
	s.mu.RLock()
	defer s.mu.RUnlock()

	targets := make([]battleSyncTarget, 0)
	for _, room := range s.roomsByID {
		if room == nil {
			continue
		}
		if room.BattleState.AssignmentID == "" {
			continue
		}
		if room.BattleState.Phase == "" || room.BattleState.Phase == "completed" || room.BattleState.Phase == "cancelled" || room.BattleState.Phase == "failed" {
			continue
		}
		targets = append(targets, battleSyncTarget{
			roomID:             room.RoomID,
			roomKind:           room.RoomKind,
			assignmentID:       room.BattleState.AssignmentID,
			assignmentRevision: room.BattleState.AssignmentRevision,
		})
	}
	return targets
}

func (s *Service) SyncBattleAssignmentStatus() []QueueStatusSyncResult {
	if s == nil || s.game == nil {
		return nil
	}

	targets := s.collectBattleSyncTargets()
	s.metrics.battleSyncTargetCount.Add(int64(len(targets)))
	if len(targets) == 0 {
		return nil
	}

	updates := make([]QueueStatusSyncResult, 0, len(targets))
	reapRequests := make([]battleReapRequest, 0, len(targets))
	for _, target := range targets {
		result, err := s.game.GetBattleAssignmentStatus(gameclient.GetBattleAssignmentStatusInput{
			RoomID:        target.roomID,
			RoomKind:      target.roomKind,
			AssignmentID:  target.assignmentID,
			KnownRevision: int64(target.assignmentRevision),
		})
		if err != nil {
			s.metrics.battleAssignmentStatusErrorCount.Add(1)
			continue
		}
		if !result.OK {
			if isBattleAssignmentGone(result) {
				if room := s.applyBattleGoneProjection(target); room != nil {
					if isManualRoomKind(target.roomKind) {
						s.metrics.manualBattleAssignmentSyncCount.Add(1)
					}
					updates = append(updates, QueueStatusSyncResult{
						RoomID:   target.roomID,
						Snapshot: room,
					})
				}
				continue
			}
			s.metrics.battleAssignmentStatusErrorCount.Add(1)
			continue
		}
		room, reapRequest := s.applyBattleAssignmentProjection(target, result)
		if room != nil {
			if isManualRoomKind(target.roomKind) {
				s.metrics.manualBattleAssignmentSyncCount.Add(1)
			}
			updates = append(updates, QueueStatusSyncResult{
				RoomID:   target.roomID,
				Snapshot: room,
			})
		}
		if reapRequest != nil {
			reapRequests = append(reapRequests, *reapRequest)
		}
	}
	for _, request := range reapRequests {
		s.executeBattleReap(request)
	}
	return updates
}

func (s *Service) applyBattleGoneProjection(target battleSyncTarget) *SnapshotProjection {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[target.roomID]
	if room == nil {
		return nil
	}
	if room.BattleState.AssignmentID != target.assignmentID {
		return nil
	}

	roomTransitionEngine.ApplyReturnCompleted(room, s.roomOwnerByID[target.roomID])
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room)
}

func (s *Service) applyBattleAssignmentProjection(target battleSyncTarget, result gameclient.GetBattleAssignmentStatusResult) (*SnapshotProjection, *battleReapRequest) {
	s.mu.Lock()
	defer s.mu.Unlock()

	room := s.roomsByID[target.roomID]
	if room == nil {
		return nil, nil
	}
	if room.BattleState.AssignmentID != target.assignmentID {
		return nil, nil
	}
	if result.AssignmentRevision > 0 && room.BattleState.AssignmentRevision > int(result.AssignmentRevision) {
		s.metrics.battleAssignmentRevisionStaleDropCount.Add(1)
		return nil, nil
	}
	if !shouldAcceptBattleAssignmentProjection(room.RoomState.Phase, result.BattlePhase, result.Finalized) {
		s.logBattleProjectionIgnoredLocked(room, result)
		return nil, nil
	}

	room.BattleState.Phase = result.BattlePhase
	room.BattleState.TerminalReason = result.TerminalReason
	room.BattleState.Ready = result.BattleEntryReady
	if result.AssignmentID != "" {
		room.BattleState.AssignmentID = result.AssignmentID
	}
	if result.AssignmentRevision > 0 {
		room.BattleState.AssignmentRevision = int(result.AssignmentRevision)
	}
	if result.MatchID != "" {
		room.BattleState.MatchID = result.MatchID
	}
	if result.BattleID != "" {
		room.BattleState.BattleID = result.BattleID
	}
	if result.ServerHost != "" {
		room.BattleState.ServerHost = result.ServerHost
	}
	if result.ServerPort > 0 {
		room.BattleState.ServerPort = int(result.ServerPort)
	}
	transitionFinalized := false
	var reapRequest *battleReapRequest = nil
	switch result.BattlePhase {
	case "allocating":
		room.RoomState.Phase = RoomPhaseBattleAllocating
	case "ready":
		room.RoomState.Phase = RoomPhaseBattleEntryReady
	case "entering":
		room.RoomState.Phase = RoomPhaseBattleEntering
	case "active":
		room.RoomState.Phase = RoomPhaseInBattle
		promoteMembersToBattle(room)
	case "returning":
		roomTransitionEngine.ApplyBattleReturning(room, s.roomOwnerByID[target.roomID], result.TerminalReason)
		transitionFinalized = true
	case "completed", "failed", "cancelled":
		roomTransitionEngine.ApplyReturnCompleted(room, s.roomOwnerByID[target.roomID])
		transitionFinalized = true
	default:
		if room.RoomState.Phase == RoomPhaseBattleAllocating || room.RoomState.Phase == RoomPhaseBattleEntryReady || room.RoomState.Phase == RoomPhaseBattleEntering {
			lockMembersForQueue(room)
		}
	}

	if !transitionFinalized {
		finalizeRoomTransition(room, s.roomOwnerByID[target.roomID])
	} else if room.BattleState.BattleID != "" {
		reapRequest = &battleReapRequest{
			roomID:       room.RoomID,
			assignmentID: room.BattleState.AssignmentID,
			battleID:     room.BattleState.BattleID,
			reason:       "terminal_phase:" + result.BattlePhase,
		}
	}
	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), reapRequest
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
	if isProtectedBattleRoomPhase(room.RoomState.Phase) && !isAuthoritativeMatchFinalizedForRoom(room, result) {
		return nil, false
	}

	changed := applyPartyQueueProjection(room, result, s.roomOwnerByID[target.roomID])
	if !changed {
		return nil, false
	}

	s.syncDirectoryEntryLocked(room)
	return s.snapshotProjectionLocked(room), true
}
