package rpcapi

import (
	"context"
	"testing"
	"time"

	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"qqtang/services/game_service/internal/queue"
)

func TestEnterAndCancelAndGetPartyQueueRPC(t *testing.T) {
	fakeQueue := &fakePartyQueueService{
		enterResult: queue.PartyQueueStatus{
			QueueState:          "queued",
			QueuePhase:          queue.QueuePhaseQueued,
			QueueTerminalReason: queue.QueueTerminalReasonNone,
			QueueStatusText:     "Matchmaking",
			QueueEntryID:        "party_queue_1",
			PartyRoomID:         "room_1",
		},
		cancelResult: queue.PartyQueueStatus{
			QueueState:          "cancelled",
			QueuePhase:          queue.QueuePhaseCompleted,
			QueueTerminalReason: queue.QueueTerminalReasonClientCancelled,
			QueueStatusText:     "Queue cancelled",
			QueueEntryID:        "party_queue_1",
			PartyRoomID:         "room_1",
		},
		statusResult: queue.PartyQueueStatus{
			QueueState:           "battle_ready",
			QueuePhase:           queue.QueuePhaseEntryReady,
			QueueTerminalReason:  queue.QueueTerminalReasonNone,
			QueueStatusText:      "Battle entry ready",
			AssignmentStatusText: "Waiting for room ticket",
			AllocationPhase:      queue.AllocationPhaseReady,
			BattleEntryReady:     true,
			QueueEntryID:         "party_queue_1",
			PartyRoomID:          "room_1",
			AssignmentID:         "assign_1",
		},
	}
	conn, cleanup := startTestRPCServer(t, NewRoomControlService(fakeQueue, nil, nil))
	defer cleanup()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	enter, err := conn.EnterPartyQueue(ctx, &gamev1.EnterPartyQueueRequest{
		Context:         &gamev1.RoomContext{RoomId: "room_1", RoomKind: "matchmade_room"},
		QueueType:       "casual",
		MatchFormatId:   "2v2",
		SelectedModeIds: []string{"mode_a"},
		Members: []*gamev1.PartyMember{
			{AccountId: "acc_1", ProfileId: "pro_1", TeamId: 1},
			{AccountId: "acc_2", ProfileId: "pro_2", TeamId: 2},
		},
	})
	if err != nil {
		t.Fatalf("enter party queue rpc failed: %v", err)
	}
	if !enter.GetOk() {
		t.Fatalf("enter party queue should succeed: %#v", enter)
	}
	if enter.GetQueuePhase() != queue.QueuePhaseQueued || enter.GetQueueTerminalReason() != queue.QueueTerminalReasonNone {
		t.Fatalf("expected canonical queued/none in enter response, got phase=%s reason=%s", enter.GetQueuePhase(), enter.GetQueueTerminalReason())
	}
	if enter.GetQueueState() != "queued" {
		t.Fatalf("expected legacy queue_state queued, got %s", enter.GetQueueState())
	}
	if fakeQueue.enterInput.PartyRoomID != "room_1" || len(fakeQueue.enterInput.Members) != 2 {
		t.Fatalf("enter input should be forwarded to queue service")
	}

	cancelResp, err := conn.CancelPartyQueue(ctx, &gamev1.CancelPartyQueueRequest{
		Context:      &gamev1.RoomContext{RoomId: "room_1"},
		QueueEntryId: "party_queue_1",
	})
	if err != nil {
		t.Fatalf("cancel party queue rpc failed: %v", err)
	}
	if !cancelResp.GetOk() {
		t.Fatalf("cancel party queue should succeed: %#v", cancelResp)
	}
	if cancelResp.GetQueuePhase() != queue.QueuePhaseCompleted || cancelResp.GetQueueTerminalReason() != queue.QueueTerminalReasonClientCancelled {
		t.Fatalf("expected canonical completed/client_cancelled in cancel response, got phase=%s reason=%s", cancelResp.GetQueuePhase(), cancelResp.GetQueueTerminalReason())
	}
	if cancelResp.GetQueueState() != "cancelled" {
		t.Fatalf("expected legacy queue_state cancelled, got %s", cancelResp.GetQueueState())
	}
	if fakeQueue.cancelPartyRoomID != "room_1" || fakeQueue.cancelQueueEntry != "party_queue_1" {
		t.Fatalf("cancel input should be forwarded to queue service")
	}

	status, err := conn.GetPartyQueueStatus(ctx, &gamev1.GetPartyQueueStatusRequest{
		Context:      &gamev1.RoomContext{RoomId: "room_1"},
		QueueEntryId: "party_queue_1",
	})
	if err != nil {
		t.Fatalf("get party queue status rpc failed: %v", err)
	}
	if !status.GetOk() {
		t.Fatalf("get party queue status should succeed: %#v", status)
	}
	if status.GetAssignmentId() != "assign_1" {
		t.Fatalf("status assignment_id mismatch: %#v", status)
	}
	if status.GetQueuePhase() != queue.QueuePhaseEntryReady || status.GetQueueTerminalReason() != queue.QueueTerminalReasonNone {
		t.Fatalf("expected canonical entry_ready/none in status response, got phase=%s reason=%s", status.GetQueuePhase(), status.GetQueueTerminalReason())
	}
	if status.GetQueueState() != "battle_ready" {
		t.Fatalf("expected legacy queue_state battle_ready, got %s", status.GetQueueState())
	}
	if !status.GetBattleEntryReady() {
		t.Fatalf("expected battle_entry_ready true")
	}
}
