package rpcapi

import (
	"testing"

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

	resp := invokeRPC(t, conn, "/qqt.internal.game.v1.RoomControlService/CommitAssignmentReady", map[string]any{
		"assignment_id":       "assign_1",
		"assignment_revision": 2,
		"account_id":          "acc_1",
		"profile_id":          "pro_1",
		"room_id":             "room_1",
	})
	if resp["ok"] != true {
		t.Fatalf("commit assignment ready should succeed: %#v", resp)
	}
	if fakeAssignment.lastInput.AssignmentID != "assign_1" || fakeAssignment.lastInput.AccountID != "acc_1" {
		t.Fatalf("commit input should be forwarded to assignment service")
	}
	if resp["commit_state"] != "committed" {
		t.Fatalf("commit state mismatch: %#v", resp)
	}
}
