package rpcapi

import (
	"testing"

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

	resp := invokeRPC(t, conn, "/qqt.internal.game.v1.RoomControlService/CreateManualRoomBattle", map[string]any{
		"source_room_id":        "room_manual_1",
		"source_room_kind":      "private_room",
		"mode_id":               "mode_classic",
		"rule_set_id":           "ruleset_classic",
		"map_id":                "map_arcade",
		"expected_member_count": 2,
		"members": []any{
			map[string]any{"account_id": "acc_1", "profile_id": "pro_1", "assigned_team_id": 1},
			map[string]any{"account_id": "acc_2", "profile_id": "pro_2", "assigned_team_id": 2},
		},
	})
	if resp["ok"] != true {
		t.Fatalf("create manual room battle should succeed: %#v", resp)
	}
	if fakeManual.lastInput.SourceRoomID != "room_manual_1" || len(fakeManual.lastInput.Members) != 2 {
		t.Fatalf("manual room input should be forwarded to service")
	}
	if resp["assignment_id"] != "assign_manual_1" {
		t.Fatalf("assignment id mismatch: %#v", resp)
	}
}
