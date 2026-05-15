package roomapp

import (
	"strings"

	"qqtang/services/room_service/internal/domain"
	"qqtang/services/room_service/internal/gameclient"
)

func (s *Service) snapshotProjectionLocked(room *domain.RoomAggregate) *SnapshotProjection {
	if room == nil {
		return nil
	}
	if isManualRoomKind(room.RoomKind) && room.QueueState.QueueEntryID != "" {
		s.metrics.queueStateManualRoomWriteCount.Add(1)
		panic("DEBT-011: manual room QueueState must remain empty")
	}
	members := make([]domain.RoomMember, 0, len(room.Members))
	for _, member := range room.Members {
		member.ReconnectToken = ""
		members = append(members, member)
	}
	capabilities := projectRoomCapabilities(room, s.roomOwnerByID[room.RoomID], s.query)
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
		MaxPlayerCount:       room.MaxPlayerCount,
		OpenSlotIndices:      append([]int{}, room.OpenSlotIndices...),
		QueuePhase:           room.QueueState.Phase,
		QueueTerminalReason:  room.QueueState.TerminalReason,
		QueueStatusText:      room.QueueState.StatusText,
		QueueErrorCode:       room.QueueState.ErrorCode,
		QueueUserMessage:     room.QueueState.UserMessage,
		QueueEntryID:         room.QueueState.QueueEntryID,
		BattlePhase:          room.BattleState.Phase,
		BattleTerminalReason: room.BattleState.TerminalReason,
		BattleStatusText:     room.BattleState.StatusText,
		Capabilities:         capabilities,
		QueueState:           room.Queue,
		BattleHandoff:        room.BattleHandoffState,
	}
}

func (s *Service) touchRoomSnapshotLocked(room *domain.RoomAggregate) {
	if room == nil {
		return
	}
	room.SnapshotRevision++
	room.RoomState.Revision = room.SnapshotRevision
	syncLegacyAliases(room)
	rebuildRoomCapabilities(room, s.roomOwnerByID[room.RoomID], s.query)
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

func shouldAcceptBattleAssignmentProjection(currentRoomPhase, resultBattlePhase string, finalized bool) bool {
	if finalized || isTerminalBattlePhase(resultBattlePhase) {
		return true
	}
	switch currentRoomPhase {
	case RoomPhaseBattleEntering:
		return battlePhaseOrder(resultBattlePhase) >= battlePhaseOrder(BattlePhaseEntering)
	case RoomPhaseInBattle:
		return battlePhaseOrder(resultBattlePhase) >= battlePhaseOrder(BattlePhaseActive)
	case RoomPhaseReturningToRoom:
		return battlePhaseOrder(resultBattlePhase) >= battlePhaseOrder(BattlePhaseReturning)
	default:
		return true
	}
}

func isTerminalBattlePhase(phase string) bool {
	switch phase {
	case BattlePhaseCompleted, "failed", "cancelled":
		return true
	default:
		return false
	}
}

func battlePhaseOrder(phase string) int {
	switch phase {
	case BattlePhaseAllocating:
		return 1
	case BattlePhaseReady:
		return 2
	case BattlePhaseEntering:
		return 3
	case BattlePhaseActive:
		return 4
	case BattlePhaseReturning:
		return 5
	case BattlePhaseCompleted, "failed", "cancelled":
		return 6
	default:
		return 0
	}
}

func isAuthoritativeMatchFinalizedForRoom(room *domain.RoomAggregate, result gameclient.GetPartyQueueStatusResult) bool {
	if room == nil {
		return false
	}
	queuePhase, terminalReason := resolveQueuePhaseAndTerminalReason(
		result.QueuePhase,
		result.QueueTerminalReason,
		result.QueueState,
		result.OK,
	)
	if queuePhase != QueuePhaseCompleted || terminalReason != QueueReasonMatchFinalized {
		return false
	}
	resultAssignmentID := strings.TrimSpace(result.AssignmentID)
	resultBattleID := strings.TrimSpace(result.BattleID)
	resultMatchID := strings.TrimSpace(result.MatchID)
	if resultAssignmentID == "" && resultBattleID == "" && resultMatchID == "" {
		return false
	}
	if resultAssignmentID != "" && room.BattleState.AssignmentID != "" && resultAssignmentID != room.BattleState.AssignmentID {
		return false
	}
	if resultBattleID != "" && room.BattleState.BattleID != "" && resultBattleID != room.BattleState.BattleID {
		return false
	}
	if resultMatchID != "" && room.BattleState.MatchID != "" && resultMatchID != room.BattleState.MatchID {
		return false
	}
	return true
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

func nonOwnerMembersReady(members map[string]domain.RoomMember, ownerMemberID string) bool {
	if len(members) < 2 {
		return false
	}
	for memberID, member := range members {
		if memberID == ownerMemberID {
			continue
		}
		if member.MemberPhase != MemberPhaseReady {
			return false
		}
	}
	return true
}

func selectNextRoomOwner(members map[string]domain.RoomMember) string {
	nextOwnerID := ""
	nextSlot := int(^uint(0) >> 1)
	for memberID, member := range members {
		slotIndex := member.SlotIndex
		if slotIndex < 0 {
			slotIndex = nextSlot
		}
		if nextOwnerID == "" || slotIndex < nextSlot || (slotIndex == nextSlot && memberID < nextOwnerID) {
			nextOwnerID = memberID
			nextSlot = slotIndex
		}
	}
	return nextOwnerID
}

func buildPartyMembers(members map[string]domain.RoomMember) []gameclient.PartyMember {
	result := make([]gameclient.PartyMember, 0, len(members))
	for _, member := range members {
		result = append(result, gameclient.PartyMember{
			AccountID:     member.AccountID,
			ProfileID:     member.ProfileID,
			TeamID:        member.TeamID,
			CharacterID:   member.Loadout.CharacterID,
			BubbleStyleID: member.Loadout.BubbleStyleID,
		})
	}
	return result
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

func isManualBattleAllocationReady(allocationState string, serverHost string, serverPort int) bool {
	switch strings.TrimSpace(allocationState) {
	case "ready", "bound_ready", "battle_ready":
		return strings.TrimSpace(serverHost) != "" && serverPort > 0
	default:
		return false
	}
}

func isBattleAssignmentGone(result gameclient.GetBattleAssignmentStatusResult) bool {
	code := strings.ToUpper(strings.TrimSpace(result.ErrorCode))
	switch code {
	case "ASSIGNMENT_NOT_FOUND", "BATTLE_NOT_FOUND", "BATTLE_REAPED", "BATTLE_FINALIZED", "NOT_FOUND", "GONE":
		return true
	case "GET_ASSIGNMENT_STATUS_FAILED":
		message := strings.ToLower(strings.TrimSpace(result.UserMessage))
		return strings.Contains(message, "not found") || strings.Contains(message, "reaped") || strings.Contains(message, "finalized")
	default:
		return false
	}
}

func (s *Service) logBattleProjectionIgnoredLocked(room *domain.RoomAggregate, result gameclient.GetBattleAssignmentStatusResult) {
	if s == nil || s.logger == nil || room == nil {
		return
	}
	s.logger.Debug(
		"battle assignment projection ignored",
		"event", "battle_assignment_projection_ignored_protected_phase",
		"room_id", room.RoomID,
		"room_kind", room.RoomKind,
		"room_phase", room.RoomState.Phase,
		"battle_phase", room.BattleState.Phase,
		"assignment_id", room.BattleState.AssignmentID,
		"assignment_revision", room.BattleState.AssignmentRevision,
		"result_battle_phase", result.BattlePhase,
		"result_terminal_reason", result.TerminalReason,
		"result_finalized", result.Finalized,
		"result_assignment_revision", result.AssignmentRevision,
	)
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
	if handoff.AssignmentRevision != 0 {
		handoff.AssignmentRevision = 0
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

func defaultOpenSlotIndices(maxPlayerCount int) []int {
	if maxPlayerCount <= 0 {
		return []int{}
	}
	result := make([]int, 0, maxPlayerCount)
	for slotIndex := 0; slotIndex < maxPlayerCount; slotIndex++ {
		result = append(result, slotIndex)
	}
	return result
}

func firstAvailableSlot(openSlotIndices []int, members map[string]domain.RoomMember) (int, bool) {
	occupied := occupiedSlotSet(members)
	normalized := normalizeSlotSet(openSlotIndices)
	for _, slotIndex := range normalized {
		if !occupied[slotIndex] {
			return slotIndex, true
		}
	}
	return 0, false
}

func normalizeOpenSlotIndices(requested []int, maxPlayerCount int, members map[string]domain.RoomMember) ([]int, error) {
	if maxPlayerCount <= 0 {
		return nil, ErrInvalidSelection
	}
	occupied := occupiedSlotSet(members)
	slotSet := map[int]struct{}{}
	for _, slotIndex := range requested {
		if slotIndex < 0 || slotIndex >= maxPlayerCount {
			return nil, ErrInvalidSelection
		}
		slotSet[slotIndex] = struct{}{}
	}
	for slotIndex := range occupied {
		if slotIndex < 0 || slotIndex >= maxPlayerCount {
			return nil, ErrInvalidSelection
		}
		slotSet[slotIndex] = struct{}{}
	}
	requiredOpenCount := len(occupied)
	if requiredOpenCount < 2 {
		requiredOpenCount = 2
	}
	if len(slotSet) < requiredOpenCount {
		return nil, ErrInvalidSelection
	}
	return sortedSlotSet(slotSet), nil
}

func expandOpenSlotIndices(current []int, maxPlayerCount int, members map[string]domain.RoomMember) []int {
	if maxPlayerCount <= 0 {
		return []int{}
	}
	slotSet := map[int]struct{}{}
	for _, slotIndex := range current {
		if slotIndex >= 0 && slotIndex < maxPlayerCount {
			slotSet[slotIndex] = struct{}{}
		}
	}
	for slotIndex := range occupiedSlotSet(members) {
		if slotIndex >= 0 && slotIndex < maxPlayerCount {
			slotSet[slotIndex] = struct{}{}
		}
	}
	for slotIndex := 0; len(slotSet) < 2 && slotIndex < maxPlayerCount; slotIndex++ {
		slotSet[slotIndex] = struct{}{}
	}
	return sortedSlotSet(slotSet)
}

func occupiedSlotSet(members map[string]domain.RoomMember) map[int]bool {
	result := map[int]bool{}
	for _, member := range members {
		if member.SlotIndex >= 0 {
			result[member.SlotIndex] = true
		}
	}
	return result
}

func normalizeSlotSet(slots []int) []int {
	slotSet := map[int]struct{}{}
	for _, slotIndex := range slots {
		if slotIndex >= 0 {
			slotSet[slotIndex] = struct{}{}
		}
	}
	return sortedSlotSet(slotSet)
}

func sortedSlotSet(slotSet map[int]struct{}) []int {
	result := make([]int, 0, len(slotSet))
	for slotIndex := range slotSet {
		result = append(result, slotIndex)
	}
	for i := 1; i < len(result); i++ {
		value := result[i]
		j := i - 1
		for j >= 0 && result[j] > value {
			result[j+1] = result[j]
			j--
		}
		result[j+1] = value
	}
	return result
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
