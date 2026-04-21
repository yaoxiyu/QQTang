package queue

import (
	"strings"

	"qqtang/services/game_service/internal/storage"
)

type NormalizedQueueProjection struct {
	QueuePhase       string
	TerminalReason   string
	AllocationPhase  string
	AllocationReason string
}

func NormalizePartyQueueStatus(entry storage.PartyQueueEntry, assignment *storage.Assignment, nowUnix int64) NormalizedQueueProjection {
	return normalizeQueueStatus(entry.State, terminalReasonOrCancelReason(entry.TerminalReason, entry.CancelReason), assignment, nowUnix)
}

func NormalizeSoloQueueStatus(entry storage.QueueEntry, assignment *storage.Assignment, nowUnix int64) NormalizedQueueProjection {
	return normalizeQueueStatus(entry.State, terminalReasonOrCancelReason(entry.TerminalReason, entry.CancelReason), assignment, nowUnix)
}

func ProjectAssignmentToQueuePhase(assignment storage.Assignment, nowUnix int64) (queuePhase string, terminalReason string, allocationPhase string, allocationReason string) {
	allocation := normalizeAllocationState(assignment.AllocationState)
	switch {
	case assignment.State == "finalized":
		return QueuePhaseCompleted, QueueTerminalReasonMatchFinalized, allocation, ""
	case assignment.CommitDeadlineUnixSec < nowUnix:
		return QueuePhaseCompleted, QueueTerminalReasonAssignmentExpired, allocation, ""
	case allocation == AllocationPhaseFailed:
		return QueuePhaseCompleted, QueueTerminalReasonAllocationFailed, allocation, QueueTerminalReasonAllocationFailed
	case allocation == AllocationPhasePending || allocation == AllocationPhaseAllocating:
		return QueuePhaseAllocatingBattle, QueueTerminalReasonNone, allocation, ""
	case allocation == AllocationPhaseReady:
		return QueuePhaseEntryReady, QueueTerminalReasonNone, allocation, ""
	default:
		return QueuePhaseAssignmentPending, QueueTerminalReasonNone, allocation, ""
	}
}

func normalizeQueueStatus(entryState string, cancelReason string, assignment *storage.Assignment, nowUnix int64) NormalizedQueueProjection {
	state := strings.TrimSpace(entryState)
	reason := strings.TrimSpace(cancelReason)
	if assignment != nil {
		qp, tr, ap, ar := ProjectAssignmentToQueuePhase(*assignment, nowUnix)
		return NormalizedQueueProjection{
			QueuePhase:       qp,
			TerminalReason:   tr,
			AllocationPhase:  ap,
			AllocationReason: ar,
		}
	}
	switch state {
	case "queued", "queueing":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseQueued,
			TerminalReason:   QueueTerminalReasonNone,
			AllocationPhase:  AllocationPhaseNone,
			AllocationReason: "",
		}
	case "assigned", "committing":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseAssignmentPending,
			TerminalReason:   QueueTerminalReasonNone,
			AllocationPhase:  AllocationPhaseNone,
			AllocationReason: "",
		}
	case "allocating":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseAllocatingBattle,
			TerminalReason:   QueueTerminalReasonNone,
			AllocationPhase:  AllocationPhaseAllocating,
			AllocationReason: "",
		}
	case "battle_ready", "matched":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseEntryReady,
			TerminalReason:   QueueTerminalReasonNone,
			AllocationPhase:  AllocationPhaseReady,
			AllocationReason: "",
		}
	case "cancelled":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseCompleted,
			TerminalReason:   mapCancelReason(reason, QueueTerminalReasonClientCancelled),
			AllocationPhase:  AllocationPhaseNone,
			AllocationReason: "",
		}
	case "failed":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseCompleted,
			TerminalReason:   mapCancelReason(reason, QueueTerminalReasonAllocationFailed),
			AllocationPhase:  AllocationPhaseFailed,
			AllocationReason: QueueTerminalReasonAllocationFailed,
		}
	case "expired":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseCompleted,
			TerminalReason:   mapCancelReason(reason, QueueTerminalReasonAssignmentExpired),
			AllocationPhase:  AllocationPhaseNone,
			AllocationReason: "",
		}
	case "finalized":
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseCompleted,
			TerminalReason:   mapCancelReason(reason, QueueTerminalReasonMatchFinalized),
			AllocationPhase:  AllocationPhaseNone,
			AllocationReason: "",
		}
	default:
		return NormalizedQueueProjection{
			QueuePhase:       QueuePhaseCompleted,
			TerminalReason:   mapCancelReason(reason, QueueTerminalReasonAllocationFailed),
			AllocationPhase:  AllocationPhaseNone,
			AllocationReason: "",
		}
	}
}

func mapCancelReason(raw string, fallback string) string {
	switch strings.TrimSpace(raw) {
	case QueueTerminalReasonClientCancelled, "party_cancelled":
		return QueueTerminalReasonClientCancelled
	case QueueTerminalReasonAssignmentExpired:
		return QueueTerminalReasonAssignmentExpired
	case QueueTerminalReasonAssignmentMissing:
		return QueueTerminalReasonAssignmentMissing
	case QueueTerminalReasonAllocationFailed:
		return QueueTerminalReasonAllocationFailed
	case QueueTerminalReasonMatchFinalized:
		return QueueTerminalReasonMatchFinalized
	case QueueTerminalReasonHeartbeatTimeout:
		return QueueTerminalReasonHeartbeatTimeout
	case "":
		return fallback
	default:
		return fallback
	}
}

func terminalReasonOrCancelReason(terminalReason string, cancelReason string) string {
	if strings.TrimSpace(terminalReason) != "" {
		return terminalReason
	}
	return cancelReason
}
