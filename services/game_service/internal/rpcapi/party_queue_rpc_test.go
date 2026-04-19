package rpcapi

import (
	"testing"

	"qqtang/services/game_service/internal/queue"
)

func TestEnterAndCancelAndGetPartyQueueRPC(t *testing.T) {
	fakeQueue := &fakePartyQueueService{
		enterResult: queue.PartyQueueStatus{
			QueueState:   "queued",
			QueueEntryID: "party_queue_1",
			PartyRoomID:  "room_1",
		},
		cancelResult: queue.PartyQueueStatus{
			QueueState:   "cancelled",
			QueueEntryID: "party_queue_1",
			PartyRoomID:  "room_1",
		},
		statusResult: queue.PartyQueueStatus{
			QueueState:   "assigned",
			QueueEntryID: "party_queue_1",
			PartyRoomID:  "room_1",
			AssignmentID: "assign_1",
		},
	}
	conn, cleanup := startTestRPCServer(t, NewRoomControlService(fakeQueue, nil, nil))
	defer cleanup()

	enter := invokeRPC(t, conn, "/qqt.internal.game.v1.RoomControlService/EnterPartyQueue", map[string]any{
		"party_room_id":     "room_1",
		"queue_type":        "casual",
		"match_format_id":   "2v2",
		"selected_mode_ids": []any{"mode_a"},
		"members": []any{
			map[string]any{"account_id": "acc_1", "profile_id": "pro_1", "device_session_id": "dev_1", "rating_snapshot": 1000},
			map[string]any{"account_id": "acc_2", "profile_id": "pro_2", "device_session_id": "dev_2", "rating_snapshot": 1002},
		},
	})
	if enter["ok"] != true {
		t.Fatalf("enter party queue should succeed: %#v", enter)
	}
	if fakeQueue.enterInput.PartyRoomID != "room_1" || len(fakeQueue.enterInput.Members) != 2 {
		t.Fatalf("enter input should be forwarded to queue service")
	}

	cancel := invokeRPC(t, conn, "/qqt.internal.game.v1.RoomControlService/CancelPartyQueue", map[string]any{
		"party_room_id":  "room_1",
		"queue_entry_id": "party_queue_1",
	})
	if cancel["ok"] != true {
		t.Fatalf("cancel party queue should succeed: %#v", cancel)
	}
	if fakeQueue.cancelPartyRoomID != "room_1" || fakeQueue.cancelQueueEntry != "party_queue_1" {
		t.Fatalf("cancel input should be forwarded to queue service")
	}

	status := invokeRPC(t, conn, "/qqt.internal.game.v1.RoomControlService/GetPartyQueueStatus", map[string]any{
		"party_room_id":  "room_1",
		"queue_entry_id": "party_queue_1",
	})
	if status["ok"] != true {
		t.Fatalf("get party queue status should succeed: %#v", status)
	}
	if status["assignment_id"] != "assign_1" {
		t.Fatalf("status assignment_id mismatch: %#v", status)
	}
}
