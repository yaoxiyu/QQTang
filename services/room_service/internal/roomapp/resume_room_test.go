package roomapp

import "testing"

func TestResumeRoom(t *testing.T) {
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
	member := created.Members[0]

	_, err = svc.ResumeRoom(ResumeRoomInput{
		RoomID:         created.RoomID,
		MemberID:       member.MemberID,
		ReconnectToken: "wrong-token",
		ConnectionID:   "conn-resume",
		RoomTicket:     mustIssueResumeRoomTicket(t, created.RoomID),
	})
	if err == nil {
		t.Fatalf("resume should fail on reconnect token mismatch")
	}

	snapshot, err := svc.ResumeRoom(ResumeRoomInput{
		RoomID:   created.RoomID,
		MemberID: member.MemberID,
		ReconnectToken: func() string {
			token, tokenErr := svc.ReconnectToken(created.RoomID, member.MemberID)
			if tokenErr != nil {
				t.Fatalf("fetch reconnect token failed: %v", tokenErr)
			}
			return token
		}(),
		ConnectionID: "conn-resume",
		RoomTicket:   mustIssueResumeRoomTicket(t, created.RoomID),
	})
	if err != nil {
		t.Fatalf("resume room failed: %v", err)
	}
	if len(snapshot.Members) != 1 {
		t.Fatalf("expected 1 member after resume, got %d", len(snapshot.Members))
	}
}
