package battlealloc

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"qqtang/services/game_service/internal/storage"
)

type fakeManualRoomRepo struct {
	assignments        map[string]storage.Assignment
	members            map[string][]storage.AssignmentMember
	failInsertMemberAt int
	insertMemberCount  int
}

func newFakeManualRoomRepo() *fakeManualRoomRepo {
	return &fakeManualRoomRepo{
		assignments: map[string]storage.Assignment{},
		members:     map[string][]storage.AssignmentMember{},
	}
}

func (r *fakeManualRoomRepo) WithTx(_ context.Context, fn func(writer manualRoomTxWriter) error) error {
	stagedAssignments := cloneAssignmentMap(r.assignments)
	stagedMembers := cloneMemberMap(r.members)
	writer := &fakeManualRoomTxWriter{
		repo:              r,
		stagedAssignments: stagedAssignments,
		stagedMembers:     stagedMembers,
	}
	if err := fn(writer); err != nil {
		return err
	}
	r.assignments = stagedAssignments
	r.members = stagedMembers
	return nil
}

func (r *fakeManualRoomRepo) UpdateAllocationState(_ context.Context, assignmentID string, allocationState string, battleID string, dsInstanceID string, battleServerHost string, battleServerPort int) error {
	assignment, ok := r.assignments[assignmentID]
	if !ok {
		return storage.ErrNotFound
	}
	assignment.AllocationState = allocationState
	assignment.BattleID = battleID
	assignment.DSInstanceID = dsInstanceID
	assignment.BattleServerHost = battleServerHost
	assignment.BattleServerPort = battleServerPort
	assignment.UpdatedAt = time.Now().UTC()
	r.assignments[assignmentID] = assignment
	return nil
}

type fakeManualRoomTxWriter struct {
	repo              *fakeManualRoomRepo
	stagedAssignments map[string]storage.Assignment
	stagedMembers     map[string][]storage.AssignmentMember
}

func (w *fakeManualRoomTxWriter) Insert(_ context.Context, assignment storage.Assignment) error {
	if _, exists := w.stagedAssignments[assignment.AssignmentID]; exists {
		return fmt.Errorf("duplicate assignment id")
	}
	w.stagedAssignments[assignment.AssignmentID] = assignment
	return nil
}

func (w *fakeManualRoomTxWriter) InsertMember(_ context.Context, member storage.AssignmentMember) error {
	w.repo.insertMemberCount++
	if w.repo.failInsertMemberAt > 0 && w.repo.insertMemberCount == w.repo.failInsertMemberAt {
		return fmt.Errorf("insert member failed")
	}
	if _, ok := w.stagedAssignments[member.AssignmentID]; !ok {
		return fmt.Errorf("assignment not found for member")
	}
	w.stagedMembers[member.AssignmentID] = append(w.stagedMembers[member.AssignmentID], member)
	return nil
}

type fakeManualRoomAllocator struct {
	err    error
	result AllocateResult
	called bool
	onCall func(input AllocateInput)
}

func (a *fakeManualRoomAllocator) AllocateBattle(_ context.Context, input AllocateInput) (AllocateResult, error) {
	a.called = true
	if a.onCall != nil {
		a.onCall(input)
	}
	if a.err != nil {
		return AllocateResult{}, a.err
	}
	return a.result, nil
}

func TestManualRoomCreateRollsBackWhenInsertMemberFails(t *testing.T) {
	repo := newFakeManualRoomRepo()
	repo.failInsertMemberAt = 2
	allocator := &fakeManualRoomAllocator{}
	service := &ManualRoomService{
		repo:      repo,
		allocator: allocator,
		nowFn:     fixedNow,
		idFn:      fixedIDs("assign_1", "battle_1", "match_1"),
	}

	_, err := service.Create(context.Background(), ManualRoomBattleInput{
		SourceRoomID: "room_manual_1",
		ModeID:       "mode_classic",
		Members: []ManualRoomMember{
			{AccountID: "a1", ProfileID: "p1", AssignedTeamID: 1},
			{AccountID: "a2", ProfileID: "p2", AssignedTeamID: 2},
		},
	})
	if !errors.Is(err, ErrManualRoomPersistFailed) {
		t.Fatalf("expected ErrManualRoomPersistFailed, got %v", err)
	}
	if len(repo.assignments) != 0 {
		t.Fatalf("expected assignments rollback, got %d", len(repo.assignments))
	}
	if len(repo.members) != 0 {
		t.Fatalf("expected member rows rollback, got %d", len(repo.members))
	}
	if allocator.called {
		t.Fatal("allocator must not be called when transaction fails")
	}
}

func TestManualRoomCreateMarksAllocationFailedWhenAllocatorFails(t *testing.T) {
	repo := newFakeManualRoomRepo()
	allocator := &fakeManualRoomAllocator{
		err: fmt.Errorf("dsm timeout"),
	}
	service := &ManualRoomService{
		repo:      repo,
		allocator: allocator,
		nowFn:     fixedNow,
		idFn:      fixedIDs("assign_1", "battle_1", "match_1"),
	}

	result, err := service.Create(context.Background(), ManualRoomBattleInput{
		SourceRoomID: "room_manual_1",
		ModeID:       "mode_classic",
		Members: []ManualRoomMember{
			{AccountID: "a1", ProfileID: "p1", AssignedTeamID: 1},
		},
	})
	if !errors.Is(err, ErrManualRoomAllocationFailed) {
		t.Fatalf("expected ErrManualRoomAllocationFailed, got %v", err)
	}
	if !allocator.called {
		t.Fatal("allocator must be called after tx commit")
	}
	assignment, ok := repo.assignments[result.AssignmentID]
	if !ok {
		t.Fatalf("assignment %s should exist after tx commit", result.AssignmentID)
	}
	if assignment.AllocationState != "allocation_failed" {
		t.Fatalf("expected allocation_failed, got %s", assignment.AllocationState)
	}
}

func TestManualRoomCreateSucceedsWithConsistentState(t *testing.T) {
	repo := newFakeManualRoomRepo()
	allocator := &fakeManualRoomAllocator{
		result: AllocateResult{
			BattleID:        "battle_1",
			DSInstanceID:    "ds_1",
			ServerHost:      "127.0.0.1",
			ServerPort:      19010,
			AllocationState: "starting",
		},
		onCall: func(_ AllocateInput) {
			assignment, ok := repo.assignments["assign_1"]
			if !ok {
				t.Fatalf("assignment should be committed before allocate")
			}
			if assignment.AllocationState != "pending_allocate" {
				t.Fatalf("expected pending_allocate before allocate, got %s", assignment.AllocationState)
			}
		},
	}
	service := &ManualRoomService{
		repo:      repo,
		allocator: allocator,
		nowFn:     fixedNow,
		idFn:      fixedIDs("assign_1", "battle_1", "match_1"),
	}

	result, err := service.Create(context.Background(), ManualRoomBattleInput{
		SourceRoomID:        "room_manual_1",
		SourceRoomKind:      "manual_room",
		ModeID:              "mode_classic",
		RuleSetID:           "ruleset_classic",
		MapID:               "map_classic_square",
		ExpectedMemberCount: 2,
		Members: []ManualRoomMember{
			{AccountID: "a1", ProfileID: "p1", AssignedTeamID: 1},
			{AccountID: "a2", ProfileID: "p2", AssignedTeamID: 2},
		},
	})
	if err != nil {
		t.Fatalf("create manual room battle failed: %v", err)
	}
	assignment, ok := repo.assignments[result.AssignmentID]
	if !ok {
		t.Fatalf("assignment %s not found", result.AssignmentID)
	}
	if assignment.AllocationState != "starting" {
		t.Fatalf("expected starting allocation state, got %s", assignment.AllocationState)
	}
	if assignment.DSInstanceID != "ds_1" || assignment.BattleServerHost != "127.0.0.1" || assignment.BattleServerPort != 19010 {
		t.Fatalf("unexpected battle endpoint: %+v", assignment)
	}
	if got := len(repo.members[result.AssignmentID]); got != 2 {
		t.Fatalf("expected 2 members, got %d", got)
	}
}

func fixedNow() time.Time {
	return time.Unix(1_700_000_000, 0).UTC()
}

func fixedIDs(ids ...string) func(prefix string) (string, error) {
	index := 0
	return func(prefix string) (string, error) {
		if index >= len(ids) {
			return "", fmt.Errorf("no more ids")
		}
		value := ids[index]
		index++
		return value, nil
	}
}

func cloneAssignmentMap(src map[string]storage.Assignment) map[string]storage.Assignment {
	dst := make(map[string]storage.Assignment, len(src))
	for key, value := range src {
		dst[key] = value
	}
	return dst
}

func cloneMemberMap(src map[string][]storage.AssignmentMember) map[string][]storage.AssignmentMember {
	dst := make(map[string][]storage.AssignmentMember, len(src))
	for key, members := range src {
		copied := make([]storage.AssignmentMember, len(members))
		copy(copied, members)
		dst[key] = copied
	}
	return dst
}
