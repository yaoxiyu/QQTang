package queue

import "testing"

func TestStateDictionaryValuesAreNonEmpty(t *testing.T) {
	values := []string{
		QueuePhaseIdle,
		QueuePhaseQueued,
		QueuePhaseAssignmentPending,
		QueuePhaseAllocatingBattle,
		QueuePhaseEntryReady,
		QueuePhaseCompleted,
		QueueTerminalReasonNone,
		QueueTerminalReasonClientCancelled,
		QueueTerminalReasonAssignmentExpired,
		QueueTerminalReasonAssignmentMissing,
		QueueTerminalReasonAllocationFailed,
		QueueTerminalReasonMatchFinalized,
		QueueTerminalReasonHeartbeatTimeout,
		AllocationPhasePending,
		AllocationPhaseAllocating,
		AllocationPhaseReady,
		AllocationPhaseFailed,
	}

	for _, value := range values {
		if value == "" {
			t.Fatalf("expected non-empty dictionary value")
		}
	}
}

func TestStateDictionaryLegacyAliasCompatibility(t *testing.T) {
	cases := []struct {
		queuePhase     string
		terminalReason string
		expectedLegacy string
	}{
		{QueuePhaseQueued, QueueTerminalReasonNone, "queued"},
		{QueuePhaseAssignmentPending, QueueTerminalReasonNone, "assigned"},
		{QueuePhaseAllocatingBattle, QueueTerminalReasonNone, "allocating"},
		{QueuePhaseEntryReady, QueueTerminalReasonNone, "battle_ready"},
		{QueuePhaseCompleted, QueueTerminalReasonClientCancelled, "cancelled"},
		{QueuePhaseCompleted, QueueTerminalReasonAssignmentExpired, "expired"},
		{QueuePhaseCompleted, QueueTerminalReasonMatchFinalized, "finalized"},
		{QueuePhaseCompleted, QueueTerminalReasonAllocationFailed, "failed"},
		{QueuePhaseCompleted, QueueTerminalReasonHeartbeatTimeout, "failed"},
	}

	for _, tc := range cases {
		if got := deriveLegacyQueueStateAlias(tc.queuePhase, tc.terminalReason); got != tc.expectedLegacy {
			t.Fatalf("deriveLegacyQueueStateAlias(%q,%q) = %q, want %q", tc.queuePhase, tc.terminalReason, got, tc.expectedLegacy)
		}
	}
}
