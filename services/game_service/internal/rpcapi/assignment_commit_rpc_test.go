package rpcapi

import (
	"context"
	"testing"
	"time"

	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"qqtang/services/game_service/internal/assignment"
)

func TestCommitAssignmentReadyRPC(t *testing.T) {
	fakeAssignment := &fakeAssignmentService{
		result: assignment.CommitResult{
			AssignmentID:       "assign_1",
			AssignmentRevision: 2,
			CommitState:        "committed",
			RoomID:             "room_1",
		},
	}
	conn, cleanup := startTestRPCServer(t, NewRoomControlService(nil, nil, fakeAssignment))
	defer cleanup()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	resp, err := conn.CommitAssignmentReady(ctx, &gamev1.CommitAssignmentReadyRequest{
		Context:      &gamev1.RoomContext{RoomId: "room_1"},
		AssignmentId: "assign_1",
		MatchId:      "match_1",
		BattleId:     "battle_1",
	})
	if err != nil {
		t.Fatalf("commit assignment ready rpc failed: %v", err)
	}
	if !resp.GetOk() {
		t.Fatalf("commit assignment ready should succeed: %#v", resp)
	}
	if fakeAssignment.lastInput.AssignmentID != "assign_1" || fakeAssignment.lastInput.RoomID != "room_1" {
		t.Fatalf("commit input should be forwarded to assignment service")
	}
	if resp.GetCommittedState() != "committed" {
		t.Fatalf("commit state mismatch: %#v", resp)
	}
}
