package battlealloc

import "context"
import "testing"

func TestManualRoomBattleTwoPhaseContract(t *testing.T) {
	t.Run("local-transaction-failure-rolls-back-all-local-state", func(t *testing.T) {
		repo := newFakeManualRoomRepo()
		repo.failInsertMemberAt = 2
		allocator := &fakeManualRoomAllocator{}
		service := &ManualRoomService{
			repo:      repo,
			allocator: allocator,
			nowFn:     fixedNow,
			idFn:      fixedIDs("assign_contract_1", "battle_contract_1", "match_contract_1"),
		}

		_, err := service.Create(context.Background(), ManualRoomBattleInput{
			SourceRoomID: "room_contract_1",
			ModeID:       "mode_contract",
			Members: []ManualRoomMember{
				{AccountID: "a1", ProfileID: "p1", AssignedTeamID: 1},
				{AccountID: "a2", ProfileID: "p2", AssignedTeamID: 2},
			},
		})
		if err == nil || err.Error() == "" {
			t.Fatal("expected local tx failure")
		}
		if len(repo.assignments) != 0 {
			t.Fatalf("expected assignment rollback, got %d", len(repo.assignments))
		}
		if len(repo.members) != 0 {
			t.Fatalf("expected member rollback, got %d", len(repo.members))
		}
		if allocator.called {
			t.Fatal("allocator must not be called when local tx failed")
		}
	})
	t.Run("external-allocate-failure-keeps-assignment-allocation-failed", func(t *testing.T) {
		repo := newFakeManualRoomRepo()
		allocator := &fakeManualRoomAllocator{err: errContract("allocator_failed")}
		service := &ManualRoomService{
			repo:      repo,
			allocator: allocator,
			nowFn:     fixedNow,
			idFn:      fixedIDs("assign_contract_2", "battle_contract_2", "match_contract_2"),
		}

		result, err := service.Create(context.Background(), ManualRoomBattleInput{
			SourceRoomID: "room_contract_2",
			ModeID:       "mode_contract",
			Members: []ManualRoomMember{
				{AccountID: "a1", ProfileID: "p1", AssignedTeamID: 1},
			},
		})
		if err == nil {
			t.Fatal("expected allocation failure")
		}
		assignment, ok := repo.assignments[result.AssignmentID]
		if !ok {
			t.Fatalf("expected assignment %s kept after external failure", result.AssignmentID)
		}
		if assignment.AllocationState != "allocation_failed" {
			t.Fatalf("expected allocation_failed, got %s", assignment.AllocationState)
		}
	})
	t.Run("full-success-advances-complete-state", func(t *testing.T) {
		repo := newFakeManualRoomRepo()
		allocator := &fakeManualRoomAllocator{
			result: AllocateResult{
				BattleID:        "battle_contract_3",
				DSInstanceID:    "ds_contract_3",
				ServerHost:      "127.0.0.1",
				ServerPort:      19100,
				AllocationState: "starting",
			},
		}
		service := &ManualRoomService{
			repo:      repo,
			allocator: allocator,
			nowFn:     fixedNow,
			idFn:      fixedIDs("assign_contract_3", "battle_contract_3", "match_contract_3"),
		}

		result, err := service.Create(context.Background(), ManualRoomBattleInput{
			SourceRoomID:        "room_contract_3",
			SourceRoomKind:      "manual_room",
			ModeID:              "mode_contract",
			RuleSetID:           "rule_contract",
			MapID:               "map_contract",
			ExpectedMemberCount: 2,
			Members: []ManualRoomMember{
				{AccountID: "a1", ProfileID: "p1", AssignedTeamID: 1},
				{AccountID: "a2", ProfileID: "p2", AssignedTeamID: 2},
			},
		})
		if err != nil {
			t.Fatalf("expected success, got error: %v", err)
		}
		assignment, ok := repo.assignments[result.AssignmentID]
		if !ok {
			t.Fatalf("expected assignment %s", result.AssignmentID)
		}
		if assignment.AllocationState != "starting" {
			t.Fatalf("expected starting state, got %s", assignment.AllocationState)
		}
		if assignment.BattleServerHost != "127.0.0.1" || assignment.BattleServerPort != 19100 {
			t.Fatalf("expected endpoint 127.0.0.1:19100, got %s:%d", assignment.BattleServerHost, assignment.BattleServerPort)
		}
		if got := len(repo.members[result.AssignmentID]); got != 2 {
			t.Fatalf("expected 2 members, got %d", got)
		}
	})
}

type contractErr string

func (e contractErr) Error() string { return string(e) }

func errContract(msg string) error { return contractErr(msg) }
