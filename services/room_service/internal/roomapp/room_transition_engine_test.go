package roomapp

import (
	"testing"

	"qqtang/services/room_service/internal/domain"
)

func TestRoomTransitionEngine_QueueAcceptedLocksMembers(t *testing.T) {
	engine := RoomTransitionEngine{}
	room := &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseReady, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseReady, Ready: true},
		},
	}
	engine.ApplyCreateRoom(room, "owner")

	engine.ApplyQueueAccepted(room, "owner", QueuePhaseQueued, QueueReasonNone, "queueing", "queue-1", "", "")

	if room.RoomState.Phase != RoomPhaseQueueActive {
		t.Fatalf("expected room phase queue_active, got %s", room.RoomState.Phase)
	}
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseQueueLocked {
			t.Fatalf("expected member phase queue_locked, got %s", member.MemberPhase)
		}
	}
}

func TestRoomTransitionEngine_QueueCompletedAllocationFailedReturnsIdle(t *testing.T) {
	engine := RoomTransitionEngine{}
	room := &domain.RoomAggregate{
		RoomKind: "casual_match_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseQueueLocked, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseQueueLocked, Ready: true},
		},
	}
	engine.ApplyCreateRoom(room, "owner")

	engine.ApplyQueueAccepted(room, "owner", QueuePhaseCompleted, QueueReasonAllocationFailed, "allocation_failed", "queue-1", "ALLOC_FAILED", "allocation failed")

	if room.RoomState.Phase != RoomPhaseIdle {
		t.Fatalf("expected room phase idle, got %s", room.RoomState.Phase)
	}
	if room.QueueState.Phase != QueuePhaseCompleted {
		t.Fatalf("expected queue phase completed, got %s", room.QueueState.Phase)
	}
	if room.QueueState.TerminalReason != QueueReasonAllocationFailed {
		t.Fatalf("expected terminal reason allocation_failed, got %s", room.QueueState.TerminalReason)
	}
}

func TestRoomTransitionEngine_ManualBattleAllocationFailedPreservesReady(t *testing.T) {
	engine := RoomTransitionEngine{}
	room := &domain.RoomAggregate{
		RoomKind: "private_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseIdle, Ready: false},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseReady, Ready: true},
		},
	}
	engine.ApplyCreateRoom(room, "owner")
	engine.ApplyManualBattleRequested(room, "owner")

	engine.ApplyManualBattleAllocationFailed(room, "owner", "ALLOC_FAILED", "allocation failed")

	if room.RoomState.Phase != RoomPhaseIdle {
		t.Fatalf("expected room phase idle, got %s", room.RoomState.Phase)
	}
	if owner := room.Members["owner"]; owner.MemberPhase != MemberPhaseIdle || owner.Ready {
		t.Fatalf("expected owner to remain idle/not-ready, got phase=%s ready=%v", owner.MemberPhase, owner.Ready)
	}
	if guest := room.Members["guest"]; guest.MemberPhase != MemberPhaseReady || !guest.Ready {
		t.Fatalf("expected guest ready state preserved, got phase=%s ready=%v", guest.MemberPhase, guest.Ready)
	}
}

func TestRoomTransitionEngine_BattleFullCycle(t *testing.T) {
	engine := RoomTransitionEngine{}
	room := &domain.RoomAggregate{
		RoomKind: "private_room",
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseReady, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseReady, Ready: true},
		},
	}
	engine.ApplyCreateRoom(room, "owner")
	engine.ApplyBattleAllocated(room, "owner", BattlePhaseReady, true)
	engine.ApplyBattleEntryAcked(room, "owner")
	if room.RoomState.Phase != RoomPhaseBattleEntering {
		t.Fatalf("expected room phase battle_entering after ack, got %s", room.RoomState.Phase)
	}
	if room.BattleState.Phase != BattlePhaseEntering {
		t.Fatalf("expected battle phase entering after ack, got %s", room.BattleState.Phase)
	}

	engine.ApplyBattleStarted(room, "owner")
	if room.RoomState.Phase != RoomPhaseInBattle {
		t.Fatalf("expected room phase in_battle, got %s", room.RoomState.Phase)
	}
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseInBattle {
			t.Fatalf("expected member phase in_battle, got %s", member.MemberPhase)
		}
	}

	engine.ApplyBattleFinished(room, "owner")
	if room.RoomState.Phase != RoomPhaseReturningToRoom {
		t.Fatalf("expected room phase returning_to_room, got %s", room.RoomState.Phase)
	}

	engine.ApplyReturnCompleted(room, "owner")
	if room.RoomState.Phase != RoomPhaseIdle {
		t.Fatalf("expected room phase idle, got %s", room.RoomState.Phase)
	}
	if room.BattleState.Phase != BattlePhaseCompleted {
		t.Fatalf("expected battle phase completed, got %s", room.BattleState.Phase)
	}
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseIdle {
			t.Fatalf("expected member phase idle after return, got %s", member.MemberPhase)
		}
		if member.Ready {
			t.Fatalf("expected ready reset to false after return")
		}
	}
}
