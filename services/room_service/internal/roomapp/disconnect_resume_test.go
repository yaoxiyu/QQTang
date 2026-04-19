package roomapp

import "testing"

func TestDisconnectThenResumeLifecycle(t *testing.T) {
	svc := newTestService(t)
	created, err := svc.CreateRoom(CreateRoomInput{
		RoomTicket:   "ticket-create",
		AccountID:    "acc-owner",
		ProfileID:    "pro-owner",
		PlayerName:   "owner",
		ConnectionID: "conn-owner",
		Loadout:      Loadout{CharacterID: "char_default", BubbleStyleID: "bubble_default"},
		Selection:    Selection{MapID: "map_arcade", RuleSetID: "ruleset_classic", ModeID: "mode_classic", MatchFormatID: "2v2"},
	})
	if err != nil {
		t.Fatalf("create room failed: %v", err)
	}
	member := created.Members[0]

	disconnected, err := svc.MarkDisconnected(created.RoomID, member.MemberID)
	if err != nil {
		t.Fatalf("mark disconnected failed: %v", err)
	}
	if disconnected.Members[0].ConnectionState != "disconnected" {
		t.Fatalf("expected disconnected state, got %s", disconnected.Members[0].ConnectionState)
	}

	token, err := svc.ReconnectToken(created.RoomID, member.MemberID)
	if err != nil {
		t.Fatalf("reconnect token failed: %v", err)
	}
	resumed, err := svc.ResumeRoom(ResumeRoomInput{
		RoomID:         created.RoomID,
		MemberID:       member.MemberID,
		ReconnectToken: token,
		ConnectionID:   "conn-resume",
		RoomTicket:     "ticket-resume",
	})
	if err != nil {
		t.Fatalf("resume room failed: %v", err)
	}
	if resumed.Members[0].ConnectionState != "connected" {
		t.Fatalf("expected connected state after resume, got %s", resumed.Members[0].ConnectionState)
	}
}
