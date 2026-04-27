package rpcapi

import (
	"context"
	"testing"

	"qqtang/services/game_service/internal/assignment"
	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"
)

func TestGetBattleAssignmentStatusMapsQueueProjectionToBattlePhase(t *testing.T) {
	cases := []struct {
		name           string
		queuePhase     string
		terminalReason string
		wantPhase      string
		wantReady      bool
		wantFinalized  bool
	}{
		{name: "entry ready", queuePhase: "entry_ready", wantPhase: "ready", wantReady: true},
		{name: "allocating", queuePhase: "allocating_battle", wantPhase: "allocating"},
		{name: "completed", queuePhase: "completed", terminalReason: "match_finalized", wantPhase: "completed", wantFinalized: true},
		{name: "allocation failed", queuePhase: "completed", terminalReason: "allocation_failed", wantPhase: "failed", wantFinalized: true},
		{name: "cancelled", queuePhase: "completed", terminalReason: "client_cancelled", wantPhase: "cancelled", wantFinalized: true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			fakeAssignment := &fakeAssignmentService{
				statusResult: assignment.StatusResult{
					AssignmentID:        "assign_1",
					RoomID:              "room_1",
					QueuePhase:          tc.queuePhase,
					QueueTerminalReason: tc.terminalReason,
				},
			}
			conn, cleanup := startTestRPCServer(t, NewRoomControlService(nil, nil, fakeAssignment))
			defer cleanup()

			resp, err := conn.GetBattleAssignmentStatus(context.Background(), &gamev1.GetBattleAssignmentStatusRequest{
				RoomId:       "room_1",
				AssignmentId: "assign_1",
			})
			if err != nil {
				t.Fatalf("get battle assignment status rpc failed: %v", err)
			}
			if !resp.GetOk() {
				t.Fatalf("get battle assignment status should succeed: %#v", resp)
			}
			if resp.GetBattlePhase() != tc.wantPhase {
				t.Fatalf("expected battle phase %s, got %s", tc.wantPhase, resp.GetBattlePhase())
			}
			if resp.GetBattleEntryReady() != tc.wantReady {
				t.Fatalf("expected ready=%v, got %v", tc.wantReady, resp.GetBattleEntryReady())
			}
			if resp.GetFinalized() != tc.wantFinalized {
				t.Fatalf("expected finalized=%v, got %v", tc.wantFinalized, resp.GetFinalized())
			}
		})
	}
}
