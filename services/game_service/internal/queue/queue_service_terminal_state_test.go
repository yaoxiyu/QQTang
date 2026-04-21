package queue

import (
	"testing"

	"qqtang/services/game_service/internal/storage"
)

func TestResolveAssignmentTerminalState(t *testing.T) {
	nowUnix := int64(1_800_000_000)

	tests := []struct {
		name         string
		assignment   storage.Assignment
		wantState    string
		wantReason   string
		wantTerminal bool
	}{
		{
			name: "finalized assignment",
			assignment: storage.Assignment{
				State:                 "finalized",
				CommitDeadlineUnixSec: nowUnix + 60,
			},
			wantState:    QueuePhaseCompleted,
			wantReason:   QueueTerminalReasonMatchFinalized,
			wantTerminal: true,
		},
		{
			name: "expired assignment deadline",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix - 1,
			},
			wantState:    QueuePhaseCompleted,
			wantReason:   QueueTerminalReasonAssignmentExpired,
			wantTerminal: true,
		},
		{
			name: "allocation failed",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix + 120,
				AllocationState:       "alloc_failed",
			},
			wantState:    QueuePhaseCompleted,
			wantReason:   QueueTerminalReasonAllocationFailed,
			wantTerminal: true,
		},
		{
			name: "allocation_failed alias",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix + 120,
				AllocationState:       "allocation_failed",
			},
			wantState:    QueuePhaseCompleted,
			wantReason:   QueueTerminalReasonAllocationFailed,
			wantTerminal: true,
		},
		{
			name: "active assignment",
			assignment: storage.Assignment{
				State:                 "assigned",
				CommitDeadlineUnixSec: nowUnix + 120,
				AllocationState:       "allocated",
			},
			wantState:    "",
			wantReason:   "",
			wantTerminal: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			gotState, gotReason, gotTerminal := resolveAssignmentTerminalState(tc.assignment, nowUnix)
			if gotState != tc.wantState || gotReason != tc.wantReason || gotTerminal != tc.wantTerminal {
				t.Fatalf("resolveAssignmentTerminalState() = (%q,%q,%v), want (%q,%q,%v)",
					gotState, gotReason, gotTerminal, tc.wantState, tc.wantReason, tc.wantTerminal)
			}
		})
	}
}
