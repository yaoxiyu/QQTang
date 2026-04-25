package roomapp

import (
	"context"
	"net"
	"os"
	"path/filepath"
	"testing"

	gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"

	"qqtang/services/room_service/internal/auth"
	"qqtang/services/room_service/internal/gameclient"
	"qqtang/services/room_service/internal/manifest"
	"qqtang/services/room_service/internal/registry"

	"google.golang.org/grpc"
)

func newTestService(t *testing.T) *Service {
	t.Helper()

	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_duel",
				"display_name": "Duel",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["1v1"],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": true
			},
			{
				"map_id": "map_arcade",
				"display_name": "Arcade",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["2v2"],
				"required_team_count": 2,
				"max_player_count": 4,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": false
			}
		],
		"modes": [
			{
				"mode_id": "mode_classic",
				"display_name": "Classic",
				"match_format_ids": ["1v1", "2v2"],
				"selectable_in_match_room": true
			}
		],
		"rules": [
			{
				"rule_set_id": "ruleset_classic",
				"display_name": "Classic Rule"
			}
		],
		"match_formats": [
			{
				"match_format_id": "1v1",
				"required_party_size": 1,
				"expected_total_player_count": 2,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			},
			{
				"match_format_id": "2v2",
				"required_party_size": 2,
				"expected_total_player_count": 4,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			}
		],
		"assets": {
			"default_character_id": "char_default",
			"default_bubble_style_id": "bubble_default",
			"legal_character_ids": ["char_default", "char_2"],
			"legal_character_skin_ids": ["skin_1"],
			"legal_bubble_style_ids": ["bubble_default", "bubble_2"],
			"legal_bubble_skin_ids": ["bubble_skin_1"]
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write test manifest: %v", err)
	}

	loader, err := manifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load test manifest: %v", err)
	}
	return NewService(
		registry.New("test-instance", "test-shard"),
		loader,
		auth.NewTicketVerifier("test-secret"),
		gameclient.New("127.0.0.1:19081"),
	)
}

func newTestServiceWithFakeGame(t *testing.T, fake *fakeGameControlServer) *Service {
	t.Helper()
	if fake == nil {
		fake = &fakeGameControlServer{}
	}

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen fake game grpc: %v", err)
	}
	grpcServer := grpc.NewServer()
	gamev1.RegisterRoomControlServiceServer(grpcServer, fake)
	go func() {
		_ = grpcServer.Serve(listener)
	}()
	t.Cleanup(func() {
		grpcServer.Stop()
		_ = listener.Close()
	})

	manifestPath := filepath.Join(t.TempDir(), "room_manifest.json")
	content := `{
		"schema_version": 1,
		"generated_at_unix_ms": 1,
		"maps": [
			{
				"map_id": "map_duel",
				"display_name": "Duel",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["1v1"],
				"required_team_count": 2,
				"max_player_count": 2,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": true
			},
			{
				"map_id": "map_arcade",
				"display_name": "Arcade",
				"mode_id": "mode_classic",
				"rule_set_id": "ruleset_classic",
				"match_format_ids": ["2v2"],
				"required_team_count": 2,
				"max_player_count": 4,
				"custom_room_enabled": true,
				"casual_enabled": true,
				"ranked_enabled": false
			}
		],
		"modes": [
			{
				"mode_id": "mode_classic",
				"display_name": "Classic",
				"match_format_ids": ["1v1", "2v2"],
				"selectable_in_match_room": true
			}
		],
		"rules": [
			{
				"rule_set_id": "ruleset_classic",
				"display_name": "Classic Rule"
			}
		],
		"match_formats": [
			{
				"match_format_id": "1v1",
				"required_party_size": 1,
				"expected_total_player_count": 2,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			},
			{
				"match_format_id": "2v2",
				"required_party_size": 2,
				"expected_total_player_count": 4,
				"legal_mode_ids": ["mode_classic"],
				"map_pool_resolution_policy": "union_by_selected_modes"
			}
		],
		"assets": {
			"default_character_id": "char_default",
			"default_bubble_style_id": "bubble_default",
			"legal_character_ids": ["char_default", "char_2"],
			"legal_character_skin_ids": ["skin_1"],
			"legal_bubble_style_ids": ["bubble_default", "bubble_2"],
			"legal_bubble_skin_ids": ["bubble_skin_1"]
		}
	}`
	if err := os.WriteFile(manifestPath, []byte(content), 0o600); err != nil {
		t.Fatalf("write test manifest: %v", err)
	}
	loader, err := manifest.LoadFromFile(manifestPath)
	if err != nil {
		t.Fatalf("load test manifest: %v", err)
	}

	return NewService(
		registry.New("test-instance", "test-shard"),
		loader,
		auth.NewTicketVerifier("test-secret"),
		gameclient.New(listener.Addr().String()),
	)
}

type fakeGameControlServer struct {
	gamev1.UnimplementedRoomControlServiceServer

	enterResp     *gamev1.EnterPartyQueueResponse
	cancelResp    *gamev1.CancelPartyQueueResponse
	statusResp    *gamev1.GetPartyQueueStatusResponse
	createResp    *gamev1.CreateManualRoomBattleResponse
	commitResp    *gamev1.CommitAssignmentReadyResponse
	lastEnterReq  *gamev1.EnterPartyQueueRequest
	lastCreateReq *gamev1.CreateManualRoomBattleRequest
	lastCommitReq *gamev1.CommitAssignmentReadyRequest
}

func (f *fakeGameControlServer) EnterPartyQueue(_ context.Context, req *gamev1.EnterPartyQueueRequest) (*gamev1.EnterPartyQueueResponse, error) {
	f.lastEnterReq = req
	if f.enterResp != nil {
		return f.enterResp, nil
	}
	return &gamev1.EnterPartyQueueResponse{Ok: true, QueueEntryId: "queue-1", QueueState: "queueing"}, nil
}

func (f *fakeGameControlServer) CancelPartyQueue(_ context.Context, _ *gamev1.CancelPartyQueueRequest) (*gamev1.CancelPartyQueueResponse, error) {
	if f.cancelResp != nil {
		return f.cancelResp, nil
	}
	return &gamev1.CancelPartyQueueResponse{Ok: true, QueueState: "cancelled"}, nil
}

func (f *fakeGameControlServer) GetPartyQueueStatus(_ context.Context, _ *gamev1.GetPartyQueueStatusRequest) (*gamev1.GetPartyQueueStatusResponse, error) {
	if f.statusResp != nil {
		return f.statusResp, nil
	}
	return &gamev1.GetPartyQueueStatusResponse{Ok: true, QueueState: "queueing"}, nil
}

func (f *fakeGameControlServer) CreateManualRoomBattle(_ context.Context, req *gamev1.CreateManualRoomBattleRequest) (*gamev1.CreateManualRoomBattleResponse, error) {
	f.lastCreateReq = req
	if f.createResp != nil {
		return f.createResp, nil
	}
	return &gamev1.CreateManualRoomBattleResponse{
		Ok:                 true,
		AssignmentId:       "assignment-1",
		MatchId:            "match-1",
		BattleId:           "battle-1",
		ServerHost:         "127.0.0.1",
		ServerPort:         19091,
		AssignmentRevision: 1,
	}, nil
}

func (f *fakeGameControlServer) CommitAssignmentReady(_ context.Context, req *gamev1.CommitAssignmentReadyRequest) (*gamev1.CommitAssignmentReadyResponse, error) {
	f.lastCommitReq = req
	if f.commitResp != nil {
		return f.commitResp, nil
	}
	return &gamev1.CommitAssignmentReadyResponse{Ok: true, CommittedState: "committed"}, nil
}
