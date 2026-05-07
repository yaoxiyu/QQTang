package roomapp

import (
	"testing"

	"qqtang/services/room_service/internal/domain"
)

func TestJoinRoom(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MapID:         "map_arcade",
			RuleSetID:     "ruleset_classic",
			ModeID:        "mode_classic",
			MatchFormatID: "2v2",
		},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}

	snapshot, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-joiner",
		ProfileID:    "pro-joiner",
		PlayerName:   "joiner",
		ConnectionID: "conn-joiner",
		Loadout: Loadout{
			CharacterID:   "char_2",
			BubbleStyleID: "bubble_2",
		},
	})
	if err != nil {
		t.Fatalf("join room failed: %v", err)
	}
	if len(snapshot.Members) != 2 {
		t.Fatalf("expected 2 members after join, got %d", len(snapshot.Members))
	}
	if snapshot.Members[0].SlotIndex == snapshot.Members[1].SlotIndex {
		t.Fatalf("expected distinct member slots, got %d", snapshot.Members[0].SlotIndex)
	}
	joiner := findMemberByAccount(t, snapshot, "acc-joiner")
	if joiner.TeamID != 2 {
		t.Fatalf("expected second member to join team B when owner is team A, got team %d", joiner.TeamID)
	}
}

func TestJoinRoomAssignsFirstDifferentTeamForSingleExistingMember(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MapID:         "map_arcade",
			RuleSetID:     "ruleset_classic",
			ModeID:        "mode_classic",
			MatchFormatID: "2v2",
		},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	if _, err := svc.UpdateProfile(UpdateProfileInput{
		RoomID:   created.RoomID,
		MemberID: created.OwnerMemberID,
		TeamID:   3,
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
	}); err != nil {
		t.Fatalf("update owner team failed: %v", err)
	}

	snapshot, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-joiner",
		ProfileID:    "pro-joiner",
		PlayerName:   "joiner",
		ConnectionID: "conn-joiner",
		Loadout: Loadout{
			CharacterID:   "char_2",
			BubbleStyleID: "bubble_2",
		},
	})
	if err != nil {
		t.Fatalf("join room failed: %v", err)
	}
	joiner := findMemberByAccount(t, snapshot, "acc-joiner")
	if joiner.TeamID != 1 {
		t.Fatalf("expected joiner to pick team A when only member is team C, got team %d", joiner.TeamID)
	}
}

func TestJoinRoomAssignsLeastPopulatedTeamWithAscendingTieBreak(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MapID:         "map_arcade",
			RuleSetID:     "ruleset_classic",
			ModeID:        "mode_classic",
			MatchFormatID: "2v2",
		},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	firstJoin, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-b",
		ProfileID:    "pro-b",
		PlayerName:   "b",
		ConnectionID: "conn-b",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("first join failed: %v", err)
	}
	memberB := findMemberByAccount(t, firstJoin, "acc-b")
	if memberB.TeamID != 2 {
		t.Fatalf("expected first joiner to pick team B, got team %d", memberB.TeamID)
	}

	snapshot, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-c",
		ProfileID:    "pro-c",
		PlayerName:   "c",
		ConnectionID: "conn-c",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("second join failed: %v", err)
	}
	memberC := findMemberByAccount(t, snapshot, "acc-c")
	if memberC.TeamID != 1 {
		t.Fatalf("expected ascending tie break to pick team A, got team %d", memberC.TeamID)
	}

	snapshot, err = svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   "ticket-join",
		AccountID:    "acc-d",
		ProfileID:    "pro-d",
		PlayerName:   "d",
		ConnectionID: "conn-d",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("third join failed: %v", err)
	}
	memberD := findMemberByAccount(t, snapshot, "acc-d")
	if memberD.TeamID != 2 {
		t.Fatalf("expected least populated team B after A has two members, got team %d", memberD.TeamID)
	}
}

func findMemberByAccount(t *testing.T, snapshot *SnapshotProjection, accountID string) domain.RoomMember {
	t.Helper()
	for _, member := range snapshot.Members {
		if member.AccountID == accountID {
			return member
		}
	}
	t.Fatalf("member account %s not found", accountID)
	return domain.RoomMember{}
}
