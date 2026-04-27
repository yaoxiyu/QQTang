package gamev1shim

import (
	inner "qqtang/services/game_service/internal/gen/qqt/internal/game/v1"

	"google.golang.org/grpc"
)

type RoomControlServiceServer = inner.RoomControlServiceServer
type UnimplementedRoomControlServiceServer = inner.UnimplementedRoomControlServiceServer
type RoomControlServiceClient = inner.RoomControlServiceClient

type RoomContext = inner.RoomContext
type PartyMember = inner.PartyMember

type EnterPartyQueueRequest = inner.EnterPartyQueueRequest
type EnterPartyQueueResponse = inner.EnterPartyQueueResponse

type CancelPartyQueueRequest = inner.CancelPartyQueueRequest
type CancelPartyQueueResponse = inner.CancelPartyQueueResponse

type GetPartyQueueStatusRequest = inner.GetPartyQueueStatusRequest
type GetPartyQueueStatusResponse = inner.GetPartyQueueStatusResponse

type CreateManualRoomBattleRequest = inner.CreateManualRoomBattleRequest
type CreateManualRoomBattleResponse = inner.CreateManualRoomBattleResponse

type CommitAssignmentReadyRequest = inner.CommitAssignmentReadyRequest
type CommitAssignmentReadyResponse = inner.CommitAssignmentReadyResponse

type GetBattleAssignmentStatusRequest = inner.GetBattleAssignmentStatusRequest
type GetBattleAssignmentStatusResponse = inner.GetBattleAssignmentStatusResponse

func RegisterRoomControlServiceServer(server grpc.ServiceRegistrar, impl RoomControlServiceServer) {
	inner.RegisterRoomControlServiceServer(server, impl)
}

func NewRoomControlServiceClient(conn grpc.ClientConnInterface) RoomControlServiceClient {
	return inner.NewRoomControlServiceClient(conn)
}
