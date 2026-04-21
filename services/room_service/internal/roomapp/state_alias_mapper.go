package roomapp

const queueReasonLegacyQueueingAlias = "__legacy_queueing_alias"

func deriveLegacyLifecycleState(roomPhase string) string {
	switch roomPhase {
	case RoomPhaseQueueEntering, RoomPhaseQueueActive, RoomPhaseQueueCancelling:
		return "queueing"
	case RoomPhaseBattleAllocating, RoomPhaseBattleEntryReady:
		return "battle_handoff"
	case RoomPhaseBattleEntering:
		return "battle_entry_acknowledged"
	case RoomPhaseInBattle:
		return "battle_entry_acknowledged"
	case RoomPhaseReturningToRoom, RoomPhaseIdle, RoomPhaseClosed:
		return "idle"
	default:
		return "idle"
	}
}

func deriveLegacyQueueState(queuePhase string, terminalReason string) string {
	switch queuePhase {
	case QueuePhaseIdle:
		return "idle"
	case QueuePhaseQueued:
		if terminalReason == queueReasonLegacyQueueingAlias {
			return "queueing"
		}
		return "queued"
	case QueuePhaseAssignmentPending:
		return "assigned"
	case QueuePhaseAllocatingBattle:
		return "allocating"
	case QueuePhaseEntryReady:
		return "battle_ready"
	case QueuePhaseCompleted:
		switch terminalReason {
		case QueueReasonClientCancelled:
			return "cancelled"
		case QueueReasonAssignmentExpired:
			return "expired"
		case QueueReasonAllocationFailed:
			return "failed"
		case QueueReasonMatchFinalized:
			return "finalized"
		case QueueReasonHeartbeatTimeout:
			return "failed"
		case QueueReasonAssignmentMissing:
			return "failed"
		default:
			return "finalized"
		}
	default:
		return "idle"
	}
}

func deriveLegacyBattleAllocationState(battlePhase string, ready bool) string {
	if ready {
		return "battle_ready"
	}
	switch battlePhase {
	case BattlePhaseIdle:
		return ""
	case BattlePhaseAllocating:
		return "allocating"
	case BattlePhaseReady:
		return "battle_ready"
	case BattlePhaseEntering, BattlePhaseActive:
		return "battle_active"
	case BattlePhaseReturning:
		return "finalizing"
	case BattlePhaseCompleted:
		return "finalized"
	default:
		return ""
	}
}
