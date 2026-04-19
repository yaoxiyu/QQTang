package rpcapi

import (
	"context"
	"errors"
	"fmt"
	"strconv"

	"google.golang.org/protobuf/types/known/structpb"

	"qqtang/services/game_service/internal/assignment"
	"qqtang/services/game_service/internal/battlealloc"
	"qqtang/services/game_service/internal/queue"
)

const RoomControlServiceName = "qqt.internal.game.v1.RoomControlService"

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
}

type RoomControlService struct {
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

func (s *RoomControlService) EnterPartyQueue(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	if s.queue == nil {
		return responseError("QUEUE_SERVICE_MISSING", "queue service is not configured"), nil
	}
	partyRoomID := getString(req, "party_room_id")
	queueType := getString(req, "queue_type")
	matchFormatID := getString(req, "match_format_id")
	selectedModeIDs := getStringList(req, "selected_mode_ids")

	membersField := getList(req, "members")
	members := make([]queue.PartyQueueMemberInput, 0, len(membersField))
	for _, rawMember := range membersField {
		memberMap, ok := rawMember.(map[string]any)
		if !ok {
			continue
		}
		members = append(members, queue.PartyQueueMemberInput{
			AccountID:       asString(memberMap["account_id"]),
			ProfileID:       asString(memberMap["profile_id"]),
			DeviceSessionID: asString(memberMap["device_session_id"]),
			RatingSnapshot:  asInt(memberMap["rating_snapshot"]),
		})
	}

	status, err := s.queue.EnterPartyQueue(ctx, queue.EnterPartyQueueInput{
		PartyRoomID:     partyRoomID,
		QueueType:       queueType,
		MatchFormatID:   matchFormatID,
		SelectedModeIDs: selectedModeIDs,
		Members:         members,
	})
	if err != nil {
		return responseError("ENTER_PARTY_QUEUE_FAILED", err.Error()), nil
	}

	return responseOK(map[string]any{
		"queue_state":            status.QueueState,
		"queue_entry_id":         status.QueueEntryID,
		"party_room_id":          status.PartyRoomID,
		"match_format_id":        status.MatchFormatID,
		"selected_mode_ids":      status.SelectedModeIDs,
		"assignment_id":          status.AssignmentID,
		"assignment_revision":    status.AssignmentRevision,
		"room_id":                status.RoomID,
		"room_kind":              status.RoomKind,
		"mode_id":                status.ModeID,
		"rule_set_id":            status.RuleSetID,
		"map_id":                 status.MapID,
		"server_host":            status.ServerHost,
		"server_port":            status.ServerPort,
		"battle_id":              status.BattleID,
		"match_id":               status.MatchID,
		"allocation_state":       status.AllocationState,
		"queue_status_text":      status.QueueStatusText,
		"assignment_status_text": status.AssignmentStatusText,
	}), nil
}

func (s *RoomControlService) CancelPartyQueue(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	if s.queue == nil {
		return responseError("QUEUE_SERVICE_MISSING", "queue service is not configured"), nil
	}
	status, err := s.queue.CancelPartyQueue(ctx, getString(req, "party_room_id"), getString(req, "queue_entry_id"))
	if err != nil {
		return responseError("CANCEL_PARTY_QUEUE_FAILED", err.Error()), nil
	}
	return responseOK(map[string]any{
		"queue_state":    status.QueueState,
		"queue_entry_id": status.QueueEntryID,
		"party_room_id":  status.PartyRoomID,
	}), nil
}

func (s *RoomControlService) GetPartyQueueStatus(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	if s.queue == nil {
		return responseError("QUEUE_SERVICE_MISSING", "queue service is not configured"), nil
	}
	status, err := s.queue.GetPartyQueueStatus(ctx, getString(req, "party_room_id"), getString(req, "queue_entry_id"))
	if err != nil {
		return responseError("GET_PARTY_QUEUE_STATUS_FAILED", err.Error()), nil
	}
	return responseOK(map[string]any{
		"queue_state":            status.QueueState,
		"queue_entry_id":         status.QueueEntryID,
		"assignment_id":          status.AssignmentID,
		"assignment_revision":    status.AssignmentRevision,
		"room_id":                status.RoomID,
		"room_kind":              status.RoomKind,
		"mode_id":                status.ModeID,
		"rule_set_id":            status.RuleSetID,
		"map_id":                 status.MapID,
		"server_host":            status.ServerHost,
		"server_port":            status.ServerPort,
		"battle_id":              status.BattleID,
		"match_id":               status.MatchID,
		"allocation_state":       status.AllocationState,
		"queue_status_text":      status.QueueStatusText,
		"assignment_status_text": status.AssignmentStatusText,
	}), nil
}

func (s *RoomControlService) CreateManualRoomBattle(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	if s.manualRoom == nil {
		return responseError("MANUAL_ROOM_SERVICE_MISSING", "manual room service is not configured"), nil
	}
	membersField := getList(req, "members")
	members := make([]battlealloc.ManualRoomMember, 0, len(membersField))
	for _, rawMember := range membersField {
		memberMap, ok := rawMember.(map[string]any)
		if !ok {
			continue
		}
		members = append(members, battlealloc.ManualRoomMember{
			AccountID:      asString(memberMap["account_id"]),
			ProfileID:      asString(memberMap["profile_id"]),
			AssignedTeamID: asInt(memberMap["assigned_team_id"]),
		})
	}
	result, err := s.manualRoom.Create(ctx, battlealloc.ManualRoomBattleInput{
		SourceRoomID:        getString(req, "source_room_id"),
		SourceRoomKind:      getString(req, "source_room_kind"),
		ModeID:              getString(req, "mode_id"),
		RuleSetID:           getString(req, "rule_set_id"),
		MapID:               getString(req, "map_id"),
		ExpectedMemberCount: getInt(req, "expected_member_count"),
		HostHint:            getString(req, "host_hint"),
		Members:             members,
	})
	if err != nil {
		return responseError("CREATE_MANUAL_ROOM_BATTLE_FAILED", err.Error()), nil
	}
	return responseOK(map[string]any{
		"assignment_id":    result.AssignmentID,
		"battle_id":        result.BattleID,
		"match_id":         result.MatchID,
		"ds_instance_id":   result.DSInstanceID,
		"server_host":      result.ServerHost,
		"server_port":      result.ServerPort,
		"allocation_state": result.AllocationState,
	}), nil
}

func (s *RoomControlService) CommitAssignmentReady(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	if s.assignment == nil {
		return responseError("ASSIGNMENT_SERVICE_MISSING", "assignment service is not configured"), nil
	}
	result, err := s.assignment.CommitRoom(ctx, assignment.CommitInput{
		AssignmentID:       getString(req, "assignment_id"),
		AssignmentRevision: getInt(req, "assignment_revision"),
		AccountID:          getString(req, "account_id"),
		ProfileID:          getString(req, "profile_id"),
		RoomID:             getString(req, "room_id"),
	})
	if err != nil {
		return responseError("COMMIT_ASSIGNMENT_READY_FAILED", err.Error()), nil
	}
	return responseOK(map[string]any{
		"assignment_id":       result.AssignmentID,
		"assignment_revision": result.AssignmentRevision,
		"commit_state":        result.CommitState,
		"room_id":             result.RoomID,
	}), nil
}

func responseOK(fields map[string]any) *structpb.Struct {
	fields["ok"] = true
	result, _ := structpb.NewStruct(normalizeMap(fields))
	return result
}

func responseError(code, message string) *structpb.Struct {
	result, _ := structpb.NewStruct(normalizeMap(map[string]any{
		"ok":         false,
		"error_code": code,
		"message":    message,
	}))
	return result
}

func getString(req *structpb.Struct, key string) string {
	if req == nil {
		return ""
	}
	return asString(req.AsMap()[key])
}

func getInt(req *structpb.Struct, key string) int {
	if req == nil {
		return 0
	}
	return asInt(req.AsMap()[key])
}

func getStringList(req *structpb.Struct, key string) []string {
	values := getList(req, key)
	result := make([]string, 0, len(values))
	for _, value := range values {
		if text := asString(value); text != "" {
			result = append(result, text)
		}
	}
	return result
}

func getList(req *structpb.Struct, key string) []any {
	if req == nil {
		return nil
	}
	raw := req.AsMap()[key]
	values, ok := raw.([]any)
	if !ok {
		return nil
	}
	return values
}

func asString(value any) string {
	switch typed := value.(type) {
	case string:
		return typed
	case fmt.Stringer:
		return typed.String()
	case float64:
		if typed == float64(int64(typed)) {
			return strconv.FormatInt(int64(typed), 10)
		}
		return strconv.FormatFloat(typed, 'f', -1, 64)
	default:
		return ""
	}
}

func asInt(value any) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int32:
		return int(typed)
	case int64:
		return int(typed)
	case float64:
		return int(typed)
	case string:
		parsed, err := strconv.Atoi(typed)
		if err != nil {
			return 0
		}
		return parsed
	default:
		return 0
	}
}

func methodNotImplemented(_ context.Context, _ *structpb.Struct) (*structpb.Struct, error) {
	return nil, errors.New("not implemented")
}

func normalizeMap(values map[string]any) map[string]any {
	result := make(map[string]any, len(values))
	for key, value := range values {
		result[key] = normalizeValue(value)
	}
	return result
}

func normalizeValue(value any) any {
	switch typed := value.(type) {
	case []string:
		items := make([]any, 0, len(typed))
		for _, item := range typed {
			items = append(items, item)
		}
		return items
	case []int:
		items := make([]any, 0, len(typed))
		for _, item := range typed {
			items = append(items, item)
		}
		return items
	case []any:
		items := make([]any, 0, len(typed))
		for _, item := range typed {
			items = append(items, normalizeValue(item))
		}
		return items
	case map[string]any:
		return normalizeMap(typed)
	default:
		return value
	}
}
