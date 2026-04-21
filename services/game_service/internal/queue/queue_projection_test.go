package queue

import (
	"testing"

	"qqtang/services/game_service/internal/storage"
)

func TestProjectAssignmentToQueuePhase(t *testing.T) {
	nowUnix := int64(1_800_000_000)

	tests := []struct {
		name                 string
		assignment           storage.Assignment
		wantQueuePhase       string
		wantTerminalReason   string
		wantAllocationPhase  string
		wantAllocationReason string
	}{
		{
			name: "finalized to completed match_finalized",
			assignment: storage.Assignment{
				State:                 "finalized",
				CommitDeadlineUnixSec: nowUnix + 60,
				AllocationState:       "allocated",
			},
			wantQueuePhase:       QueuePhaseCompleted,
			wantTerminalReason:   QueueTerminalReasonMatchFinalized,
			wantAllocationPhase:  AllocationPhaseReady,
			wantAllocationReason: "",
		},
		{
			name: "expired to completed assignment_expired",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix - 1,
				AllocationState:       "allocated",
			},
			wantQueuePhase:       QueuePhaseCompleted,
			wantTerminalReason:   QueueTerminalReasonAssignmentExpired,
			wantAllocationPhase:  AllocationPhaseReady,
			wantAllocationReason: "",
		},
		{
			name: "allocation failed to completed allocation_failed",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix + 60,
				AllocationState:       "alloc_failed",
			},
			wantQueuePhase:       QueuePhaseCompleted,
			wantTerminalReason:   QueueTerminalReasonAllocationFailed,
			wantAllocationPhase:  AllocationPhaseFailed,
			wantAllocationReason: QueueTerminalReasonAllocationFailed,
		},
		{
			name: "allocating to allocating_battle",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix + 60,
				AllocationState:       "allocating",
			},
			wantQueuePhase:       QueuePhaseAllocatingBattle,
			wantTerminalReason:   QueueTerminalReasonNone,
			wantAllocationPhase:  AllocationPhaseAllocating,
			wantAllocationReason: "",
		},
		{
			name: "allocated to entry_ready",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix + 60,
				AllocationState:       "allocated",
			},
			wantQueuePhase:       QueuePhaseEntryReady,
			wantTerminalReason:   QueueTerminalReasonNone,
			wantAllocationPhase:  AllocationPhaseReady,
			wantAllocationReason: "",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			gotQueuePhase, gotTerminalReason, gotAllocationPhase, gotAllocationReason := ProjectAssignmentToQueuePhase(tc.assignment, nowUnix)
			if gotQueuePhase != tc.wantQueuePhase ||
				gotTerminalReason != tc.wantTerminalReason ||
				gotAllocationPhase != tc.wantAllocationPhase ||
				gotAllocationReason != tc.wantAllocationReason {
				t.Fatalf("ProjectAssignmentToQueuePhase() = (%q,%q,%q,%q), want (%q,%q,%q,%q)",
					gotQueuePhase, gotTerminalReason, gotAllocationPhase, gotAllocationReason,
					tc.wantQueuePhase, tc.wantTerminalReason, tc.wantAllocationPhase, tc.wantAllocationReason,
				)
			}
		})
	}
}

func TestNormalizeQueueStatus_CompletedHeartbeatTimeout(t *testing.T) {
	projection := normalizeQueueStatus("completed", QueueTerminalReasonHeartbeatTimeout, nil, 1_800_000_000)
	if projection.QueuePhase != QueuePhaseCompleted {
		t.Fatalf("expected queue phase completed, got %s", projection.QueuePhase)
	}
	if projection.TerminalReason != QueueTerminalReasonHeartbeatTimeout {
		t.Fatalf("expected terminal reason heartbeat_timeout, got %s", projection.TerminalReason)
	}
	if alias := deriveLegacyQueueStateAlias(projection.QueuePhase, projection.TerminalReason); alias != "failed" {
		t.Fatalf("expected legacy alias failed, got %s", alias)
	}
}
