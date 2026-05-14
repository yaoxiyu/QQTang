package roomapp

import (
	"testing"
	"time"

	"qqtang/services/room_service/internal/domain"
)

func TestLeaveRoom(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout: Loadout{
			CharacterID:   "char_default",
			BubbleStyleID: "bubble_default",
		},
		Selection: Selection{
			MapID:     "map_arcade",
			RuleSetID: "ruleset_classic",
			ModeID:    "mode_classic",
		},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	memberID := created.Members[0].MemberID

	snapshot, err := svc.LeaveRoom(LeaveRoomInput{
		RoomID:   created.RoomID,
		MemberID: memberID,
	})
	if err != nil {
		t.Fatalf("leave room failed: %v", err)
	}
	if snapshot != nil {
		t.Fatalf("last member leave should remove room and return nil snapshot")
	}
	if _, err := svc.SnapshotProjection(created.RoomID); err == nil {
		t.Fatalf("room should not exist after last member leaves")
	}
}

func TestLeaveRoomTransfersOwnerToLowestOccupiedSlot(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	joined, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       created.RoomID,
		RoomTicket:   mustIssueJoinRoomTicket(t, created.RoomID, "acc-joiner", "pro-joiner"),
		AccountID:    "acc-joiner",
		ProfileID:    "pro-joiner",
		PlayerName:   "joiner",
		ConnectionID: "conn-joiner",
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("join room failed: %v", err)
	}
	nextOwnerID := ""
	for _, member := range joined.Members {
		if member.MemberID != created.OwnerMemberID {
			nextOwnerID = member.MemberID
			break
		}
	}
	if nextOwnerID == "" {
		t.Fatalf("expected joined member")
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: nextOwnerID}); err != nil {
		t.Fatalf("toggle joiner ready failed: %v", err)
	}

	snapshot, err := svc.LeaveRoom(LeaveRoomInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("owner leave failed: %v", err)
	}
	if snapshot == nil {
		t.Fatalf("expected remaining room snapshot")
	}
	if snapshot.OwnerMemberID != nextOwnerID {
		t.Fatalf("expected owner transfer to %s, got %s", nextOwnerID, snapshot.OwnerMemberID)
	}
	if !snapshot.Capabilities.CanUpdateSelection {
		t.Fatalf("expected transferred owner to edit custom room selection")
	}
	if snapshot.Capabilities.CanStartManualBattle {
		t.Fatalf("expected single remaining member cannot start")
	}
}

func TestOwnerLeaveResetsTransferredOwnerAndRebuildsStartCapability(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomKind:     "private_room",
		RoomTicket:   mustIssueCreateRoomTicket(t, "private_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}

	firstGuest := joinMemberForLeaveTest(t, svc, created.RoomID, "first", 2)
	secondGuest := joinMemberForLeaveTest(t, svc, created.RoomID, "second", 1)
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: firstGuest}); err != nil {
		t.Fatalf("first guest ready failed: %v", err)
	}
	if _, err := svc.ToggleReady(ToggleReadyInput{RoomID: created.RoomID, MemberID: secondGuest}); err != nil {
		t.Fatalf("second guest ready failed: %v", err)
	}

	snapshot, err := svc.LeaveRoom(LeaveRoomInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("owner leave failed: %v", err)
	}
	if snapshot.OwnerMemberID != firstGuest {
		t.Fatalf("expected first guest to become owner, got %s", snapshot.OwnerMemberID)
	}
	transferredOwner := findProjectedMember(t, snapshot, firstGuest)
	if transferredOwner.Ready || transferredOwner.MemberPhase != MemberPhaseIdle {
		t.Fatalf("expected transferred owner reset to lobby idle/not-ready, got phase=%s ready=%v", transferredOwner.MemberPhase, transferredOwner.Ready)
	}
	remainingGuest := findProjectedMember(t, snapshot, secondGuest)
	if !remainingGuest.Ready || remainingGuest.MemberPhase != MemberPhaseReady {
		t.Fatalf("expected non-owner ready state preserved, got phase=%s ready=%v", remainingGuest.MemberPhase, remainingGuest.Ready)
	}
	if !snapshot.Capabilities.CanStartManualBattle {
		t.Fatalf("expected start capability rebuilt after owner transfer")
	}
}

func TestLeaveRoomDelaysEmptyBattleRoomCleanup(t *testing.T) {
	svc := newTestService(t)
	svc.SetEmptyBattleCleanupGrace(time.Millisecond)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}

	svc.mu.Lock()
	room := svc.roomsByID[created.RoomID]
	room.RoomState.Phase = RoomPhaseInBattle
	room.BattleState.Phase = BattlePhaseActive
	room.BattleState.AssignmentID = "assign-cleanup"
	room.BattleState.BattleID = "battle-cleanup"
	svc.mu.Unlock()

	snapshot, err := svc.LeaveRoom(LeaveRoomInput{RoomID: created.RoomID, MemberID: created.OwnerMemberID})
	if err != nil {
		t.Fatalf("leave room failed: %v", err)
	}
	if snapshot != nil {
		t.Fatalf("last battle member leave should return nil snapshot")
	}
	if _, err := svc.SnapshotProjection(created.RoomID); err != nil {
		t.Fatalf("battle room should stay until cleanup grace expires: %v", err)
	}

	svc.SweepEmptyBattleRooms(time.Now().Add(time.Second))
	if _, err := svc.SnapshotProjection(created.RoomID); err == nil {
		t.Fatalf("battle room should be destroyed after cleanup grace")
	}
}

func TestMarkDisconnectedHidesAndCleansUpEmptyBattleRoom(t *testing.T) {
	svc := newTestService(t)
	svc.SetEmptyBattleCleanupGrace(time.Millisecond)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   mustIssueCreateRoomTicket(t, "custom_room", "acc-owner", "pro-owner"),
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	guest := joinMemberForLeaveTest(t, svc, created.RoomID, "guest", 1)
	if got := len(svc.DirectorySnapshot("127.0.0.1", 9100).GetEntries()); got != 1 {
		t.Fatalf("expected room visible before all members disconnect, got %d entries", got)
	}

	svc.mu.Lock()
	room := svc.roomsByID[created.RoomID]
	room.BattleState.Phase = BattlePhaseActive
	room.BattleState.AssignmentID = "assign-disconnect-cleanup"
	room.BattleState.BattleID = "battle-disconnect-cleanup"
	svc.mu.Unlock()

	if _, err := svc.MarkDisconnected(created.RoomID, created.OwnerMemberID); err != nil {
		t.Fatalf("mark owner disconnected failed: %v", err)
	}
	if got := len(svc.DirectorySnapshot("127.0.0.1", 9100).GetEntries()); got != 1 {
		t.Fatalf("expected room still visible while one member remains connected, got %d entries", got)
	}
	if _, err := svc.MarkDisconnected(created.RoomID, guest); err != nil {
		t.Fatalf("mark guest disconnected failed: %v", err)
	}
	if got := len(svc.DirectorySnapshot("127.0.0.1", 9100).GetEntries()); got != 0 {
		t.Fatalf("expected empty disconnected battle room hidden from directory, got %d entries", got)
	}
	if _, err := svc.SnapshotProjection(created.RoomID); err != nil {
		t.Fatalf("battle room should remain resumable until cleanup grace expires: %v", err)
	}

	if swept := svc.SweepEmptyBattleRooms(time.Now().Add(time.Second)); swept != 1 {
		t.Fatalf("expected one empty battle room swept, got %d", swept)
	}
	if _, err := svc.SnapshotProjection(created.RoomID); err == nil {
		t.Fatalf("battle room should be destroyed after cleanup grace")
	}
}

func joinMemberForLeaveTest(t *testing.T, svc *Service, roomID string, name string, teamID int) string {
	t.Helper()
	snapshot, err := svc.JoinRoom(JoinRoomInput{
		RoomID:       roomID,
		RoomTicket:   mustIssueJoinRoomTicket(t, roomID, "acc-"+name, "pro-"+name),
		AccountID:    "acc-" + name,
		ProfileID:    "pro-" + name,
		PlayerName:   name,
		ConnectionID: "conn-" + name,
		Loadout:      Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
	})
	if err != nil {
		t.Fatalf("join %s failed: %v", name, err)
	}
	memberID := ""
	for _, member := range snapshot.Members {
		if member.PlayerName == name {
			memberID = member.MemberID
			break
		}
	}
	if memberID == "" {
		t.Fatalf("member %s not found after join", name)
	}
	if _, err := svc.UpdateProfile(UpdateProfileInput{
		RoomID:     roomID,
		MemberID:   memberID,
		TeamID:     teamID,
		Loadout:    Loadout{CharacterID: "char_2", BubbleStyleID: "bubble_2"},
		PlayerName: name,
	}); err != nil {
		t.Fatalf("update %s failed: %v", name, err)
	}
	return memberID
}

func findProjectedMember(t *testing.T, snapshot *SnapshotProjection, memberID string) domain.RoomMember {
	t.Helper()
	for _, member := range snapshot.Members {
		if member.MemberID == memberID {
			return member
		}
	}
	t.Fatalf("member %s not found in snapshot", memberID)
	return domain.RoomMember{}
}
