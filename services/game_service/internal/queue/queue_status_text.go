package queue

func buildQueueStatusText(queuePhase string, terminalReason string) string {
	switch queuePhase {
	case QueuePhaseQueued:
		return "Matchmaking"
	case QueuePhaseAssignmentPending:
		return "Match found"
	case QueuePhaseAllocatingBattle:
		return "Allocating battle server"
	case QueuePhaseEntryReady:
		return "Battle entry ready"
	case QueuePhaseCompleted:
		switch terminalReason {
		case QueueTerminalReasonClientCancelled:
			return "Queue cancelled"
		case QueueTerminalReasonAssignmentExpired:
			return "Assignment expired"
		case QueueTerminalReasonAllocationFailed:
			return "Battle allocation failed"
		case QueueTerminalReasonMatchFinalized:
			return "Match finalized"
		case QueueTerminalReasonHeartbeatTimeout:
			return "Queue heartbeat timeout"
		case QueueTerminalReasonAssignmentMissing:
			return "Assignment missing"
		default:
			return "Queue completed"
		}
	default:
		return "Queue idle"
	}
}
