package roomapp

import (
	"testing"

	"qqtang/services/room_service/internal/domain"
)

func TestToggleMemberReadyRejectsNonIdleMemberPhase(t *testing.T) {
	room := &domain.RoomAggregate{
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseQueueLocked, Ready: false},
		},
	}

	if ok := toggleMemberReady(room, "owner"); ok {
		t.Fatalf("expected toggleMemberReady rejected when member is queue_locked")
	}
	if room.Members["owner"].Ready {
		t.Fatalf("expected ready unchanged")
	}
}

func TestMemberTransitionHelpers_PromoteAndRelease(t *testing.T) {
	room := &domain.RoomAggregate{
		Members: map[string]domain.RoomMember{
			"owner": {MemberID: "owner", MemberPhase: MemberPhaseQueueLocked, Ready: true},
			"guest": {MemberID: "guest", MemberPhase: MemberPhaseQueueLocked, Ready: true},
		},
	}

	promoteMembersToBattle(room)
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseInBattle {
			t.Fatalf("expected member phase in_battle, got %s", member.MemberPhase)
		}
	}

	releaseMembersToIdle(room)
	for _, member := range room.Members {
		if member.MemberPhase != MemberPhaseIdle {
			t.Fatalf("expected member phase idle, got %s", member.MemberPhase)
		}
		if member.Ready {
			t.Fatalf("expected ready reset after release")
		}
	}
}
