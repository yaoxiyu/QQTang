package rpcapi

import (
	"context"
	"testing"
	"time"

	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"qqtang/services/game_service/internal/battlealloc"
)

func TestCreateManualRoomBattleRPC(t *testing.T) {
	fakeManual := &fakeManualRoomService{
		result: battlealloc.ManualRoomBattleResult{
			AssignmentID:    "assign_manual_1",
			BattleID:        "battle_1",
			MatchID:         "match_1",
			DSInstanceID:    "ds_1",
			ServerHost:      "127.0.0.1",
			ServerPort:      19111,
			AllocationState: "starting",
		},
	}
	conn, cleanup := startTestRPCServer(t, NewRoomControlService(nil, fakeManual, nil))
	defer cleanup()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	resp, err := conn.CreateManualRoomBattle(ctx, &gamev1.CreateManualRoomBattleRequest{
		Context:   &gamev1.RoomContext{RoomId: "room_manual_1", RoomKind: "private_room"},
		ModeId:    "mode_classic",
		RuleSetId: "ruleset_classic",
		MapId:     "map_arcade",
		Members: []*gamev1.PartyMember{
			{AccountId: "acc_1", ProfileId: "pro_1", TeamId: 1},
			{AccountId: "acc_2", ProfileId: "pro_2", TeamId: 2},
		},
	})
	if err != nil {
		t.Fatalf("create manual room battle rpc failed: %v", err)
	}
	if !resp.GetOk() {
		t.Fatalf("create manual room battle should succeed: %#v", resp)
	}
	if fakeManual.lastInput.SourceRoomID != "room_manual_1" || len(fakeManual.lastInput.Members) != 2 {
		t.Fatalf("manual room input should be forwarded to service")
	}
	if resp.GetAssignmentId() != "assign_manual_1" {
		t.Fatalf("assignment id mismatch: %#v", resp)
	}
}
