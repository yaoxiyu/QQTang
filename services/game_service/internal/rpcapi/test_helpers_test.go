package rpcapi

import (
	"context"
	"net"
	"testing"
	"time"

	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/queue"
)

type fakePartyQueueService struct {
	enterInput        queue.EnterPartyQueueInput
	cancelPartyRoomID string
	cancelQueueEntry  string
	statusPartyRoomID string
	statusQueueEntry  string
	enterResult       queue.PartyQueueStatus
	cancelResult      queue.PartyQueueStatus
	statusResult      queue.PartyQueueStatus
	err               error
}

func (f *fakePartyQueueService) EnterPartyQueue(_ context.Context, input queue.EnterPartyQueueInput) (queue.PartyQueueStatus, error) {
	f.enterInput = input
	return f.enterResult, f.err
}

func (f *fakePartyQueueService) CancelPartyQueue(_ context.Context, partyRoomID string, queueEntryID string) (queue.PartyQueueStatus, error) {
	f.cancelPartyRoomID = partyRoomID
	f.cancelQueueEntry = queueEntryID
	return f.cancelResult, f.err
}

func (f *fakePartyQueueService) GetPartyQueueStatus(_ context.Context, partyRoomID string, queueEntryID string) (queue.PartyQueueStatus, error) {
	f.statusPartyRoomID = partyRoomID
	f.statusQueueEntry = queueEntryID
	return f.statusResult, f.err
}

type fakeManualRoomService struct {
	lastInput battlealloc.ManualRoomBattleInput
	result    battlealloc.ManualRoomBattleResult
	err       error
}

func (f *fakeManualRoomService) Create(_ context.Context, input battlealloc.ManualRoomBattleInput) (battlealloc.ManualRoomBattleResult, error) {
	f.lastInput = input
	return f.result, f.err
}

type fakeAssignmentService struct {
	lastInput    assignment.CommitInput
	result       assignment.CommitResult
	statusResult assignment.StatusResult
	err          error
}

func (f *fakeAssignmentService) CommitRoom(_ context.Context, input assignment.CommitInput) (assignment.CommitResult, error) {
	f.lastInput = input
	return f.result, f.err
}

func (f *fakeAssignmentService) CommitBattleEntryReady(_ context.Context, input assignment.CommitInput) (assignment.CommitResult, error) {
	f.lastInput = input
	return f.result, f.err
}

func (f *fakeAssignmentService) GetStatus(_ context.Context, roomID string, assignmentID string) (assignment.StatusResult, error) {
	if f.statusResult.AssignmentID != "" || f.statusResult.RoomID != "" || f.statusResult.QueuePhase != "" {
		status := f.statusResult
		if status.AssignmentID == "" {
			status.AssignmentID = assignmentID
		}
		if status.RoomID == "" {
			status.RoomID = roomID
		}
		return status, f.err
	}
	return assignment.StatusResult{
		AssignmentID: assignmentID,
		RoomID:       roomID,
		QueueState:   "battle_ready",
		QueuePhase:   "entry_ready",
	}, f.err
}

func startTestRPCServer(t *testing.T, svc *RoomControlService) (gamev1.RoomControlServiceClient, func()) {
	t.Helper()
	grpcServer := grpc.NewServer()
	RegisterRoomControlService(grpcServer, svc)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen grpc test server: %v", err)
	}
	go func() {
		_ = grpcServer.Serve(ln)
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	conn, err := grpc.DialContext(ctx, ln.Addr().String(), grpc.WithTransportCredentials(insecure.NewCredentials()), grpc.WithBlock())
	if err != nil {
		grpcServer.Stop()
		_ = ln.Close()
		t.Fatalf("dial grpc test server: %v", err)
	}

	cleanup := func() {
		_ = conn.Close()
		grpcServer.Stop()
		_ = ln.Close()
	}
	return gamev1.NewRoomControlServiceClient(conn), cleanup
}
