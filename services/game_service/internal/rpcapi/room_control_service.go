package rpcapi

import (
	"context"

	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/queue"
)

type PartyQueueService interface {
	EnterPartyQueue(ctx context.Context, input queue.EnterPartyQueueInput) (queue.PartyQueueStatus, error)
	CancelPartyQueue(ctx context.Context, partyRoomID string, queueEntryID string) (queue.PartyQueueStatus, error)
	GetPartyQueueStatus(ctx context.Context, partyRoomID string, queueEntryID string) (queue.PartyQueueStatus, error)
}

type ManualRoomBattleService interface {
	Create(ctx context.Context, input battlealloc.ManualRoomBattleInput) (battlealloc.ManualRoomBattleResult, error)
}

type AssignmentCommitService interface {
	CommitRoom(ctx context.Context, input assignment.CommitInput) (assignment.CommitResult, error)
	CommitBattleEntryReady(ctx context.Context, input assignment.CommitInput) (assignment.CommitResult, error)
	GetStatus(ctx context.Context, roomID string, assignmentID string) (assignment.StatusResult, error)
}

type RoomControlService struct {
	gamev1.UnimplementedRoomControlServiceServer

	queue      PartyQueueService
	manualRoom ManualRoomBattleService
	assignment AssignmentCommitService
}

func NewRoomControlService(queueService PartyQueueService, manualRoomService ManualRoomBattleService, assignmentService AssignmentCommitService) *RoomControlService {
	return &RoomControlService{
		queue:      queueService,
		manualRoom: manualRoomService,
		assignment: assignmentService,
	}
}

func (s *RoomControlService) EnterPartyQueue(ctx context.Context, req *gamev1.EnterPartyQueueRequest) (*gamev1.EnterPartyQueueResponse, error) {
	if s.queue == nil {
		return errorEnterPartyQueue("QUEUE_SERVICE_MISSING", "queue service is not configured"), nil
	}
	status, err := s.queue.EnterPartyQueue(ctx, mapEnterPartyQueueInput(req))
	if err != nil {
		return errorEnterPartyQueue("ENTER_PARTY_QUEUE_FAILED", err.Error()), nil
	}
	return successEnterPartyQueue(status), nil
}

func (s *RoomControlService) CancelPartyQueue(ctx context.Context, req *gamev1.CancelPartyQueueRequest) (*gamev1.CancelPartyQueueResponse, error) {
	if s.queue == nil {
		return errorCancelPartyQueue("QUEUE_SERVICE_MISSING", "queue service is not configured"), nil
	}
	status, err := s.queue.CancelPartyQueue(ctx, roomIDFromContext(req.GetContext()), req.GetQueueEntryId())
	if err != nil {
		return errorCancelPartyQueue("CANCEL_PARTY_QUEUE_FAILED", err.Error()), nil
	}
	return successCancelPartyQueue(status), nil
}

func (s *RoomControlService) GetPartyQueueStatus(ctx context.Context, req *gamev1.GetPartyQueueStatusRequest) (*gamev1.GetPartyQueueStatusResponse, error) {
	if s.queue == nil {
		return errorGetPartyQueueStatus("QUEUE_SERVICE_MISSING", "queue service is not configured"), nil
	}
	roomID := roomIDFromContext(req.GetContext())
	queueEntryID := req.GetQueueEntryId()
	status, err := s.queue.GetPartyQueueStatus(ctx, roomID, queueEntryID)
	if err != nil {
		return errorGetPartyQueueStatus("GET_PARTY_QUEUE_STATUS_FAILED", err.Error()), nil
	}
	return successGetPartyQueueStatus(status), nil
}

func (s *RoomControlService) CreateManualRoomBattle(ctx context.Context, req *gamev1.CreateManualRoomBattleRequest) (*gamev1.CreateManualRoomBattleResponse, error) {
	if s.manualRoom == nil {
		return errorCreateManualRoomBattle("MANUAL_ROOM_SERVICE_MISSING", "manual room service is not configured"), nil
	}
	result, err := s.manualRoom.Create(ctx, mapCreateManualRoomBattleInput(req))
	if err != nil {
		return errorCreateManualRoomBattle("CREATE_MANUAL_ROOM_BATTLE_FAILED", err.Error()), nil
	}
	return successCreateManualRoomBattle(result), nil
}

func (s *RoomControlService) GetBattleAssignmentStatus(ctx context.Context, req *gamev1.GetBattleAssignmentStatusRequest) (*gamev1.GetBattleAssignmentStatusResponse, error) {
	if req.GetRoomId() == "" {
		return errorGetBattleAssignmentStatus("ROOM_ID_MISSING", "room_id is required"), nil
	}
	if req.GetAssignmentId() == "" {
		return errorGetBattleAssignmentStatus("ASSIGNMENT_ID_MISSING", "assignment_id is required"), nil
	}
	if s.assignment == nil {
		return errorGetBattleAssignmentStatus("ASSIGNMENT_SERVICE_MISSING", "assignment service is not configured"), nil
	}
	status, err := s.assignment.GetStatus(ctx, req.GetRoomId(), req.GetAssignmentId())
	if err != nil {
		return errorGetBattleAssignmentStatus("GET_ASSIGNMENT_STATUS_FAILED", err.Error()), nil
	}
	if status.AssignmentID == "" {
		return errorGetBattleAssignmentStatus("ASSIGNMENT_NOT_FOUND", "assignment not found"), nil
	}
	if status.RoomID != "" && status.RoomID != req.GetRoomId() {
		return errorGetBattleAssignmentStatus("ASSIGNMENT_ROOM_MISMATCH", "assignment does not belong to room"), nil
	}
	return successGetBattleAssignmentStatus(status), nil
}

func (s *RoomControlService) CommitAssignmentReady(ctx context.Context, req *gamev1.CommitAssignmentReadyRequest) (*gamev1.CommitAssignmentReadyResponse, error) {
	if s.assignment == nil {
		return errorCommitAssignmentReady("ASSIGNMENT_SERVICE_MISSING", "assignment service is not configured"), nil
	}
	result, err := s.assignment.CommitBattleEntryReady(ctx, mapCommitAssignmentReadyInput(req))
	if err != nil {
		return errorCommitAssignmentReady("COMMIT_ASSIGNMENT_READY_FAILED", err.Error()), nil
	}
	return successCommitAssignmentReady(result), nil
}
