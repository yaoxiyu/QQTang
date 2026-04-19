package rpcapi

import (
	"context"
	"fmt"
	"net"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/structpb"
)

type handlerFunc func(context.Context, *structpb.Struct) (*structpb.Struct, error)

type grpcService struct {
	enterPartyQueue        handlerFunc
	cancelPartyQueue       handlerFunc
	getPartyQueueStatus    handlerFunc
	createManualRoomBattle handlerFunc
	commitAssignmentReady  handlerFunc
}

type roomControlServer interface {
	EnterPartyQueue(context.Context, *structpb.Struct) (*structpb.Struct, error)
	CancelPartyQueue(context.Context, *structpb.Struct) (*structpb.Struct, error)
	GetPartyQueueStatus(context.Context, *structpb.Struct) (*structpb.Struct, error)
	CreateManualRoomBattle(context.Context, *structpb.Struct) (*structpb.Struct, error)
	CommitAssignmentReady(context.Context, *structpb.Struct) (*structpb.Struct, error)
}

func RegisterRoomControlService(server *grpc.Server, service *RoomControlService) {
	impl := &grpcService{
		enterPartyQueue:        service.EnterPartyQueue,
		cancelPartyQueue:       service.CancelPartyQueue,
		getPartyQueueStatus:    service.GetPartyQueueStatus,
		createManualRoomBattle: service.CreateManualRoomBattle,
		commitAssignmentReady:  service.CommitAssignmentReady,
	}
	server.RegisterService(&grpc.ServiceDesc{
		ServiceName: RoomControlServiceName,
		HandlerType: (*roomControlServer)(nil),
		Methods: []grpc.MethodDesc{
			{MethodName: "EnterPartyQueue", Handler: impl.wrap("EnterPartyQueue", impl.enterPartyQueue)},
			{MethodName: "CancelPartyQueue", Handler: impl.wrap("CancelPartyQueue", impl.cancelPartyQueue)},
			{MethodName: "GetPartyQueueStatus", Handler: impl.wrap("GetPartyQueueStatus", impl.getPartyQueueStatus)},
			{MethodName: "CreateManualRoomBattle", Handler: impl.wrap("CreateManualRoomBattle", impl.createManualRoomBattle)},
			{MethodName: "CommitAssignmentReady", Handler: impl.wrap("CommitAssignmentReady", impl.commitAssignmentReady)},
		},
		Streams:  []grpc.StreamDesc{},
		Metadata: "proto/qqt/internal/game/v1/room_control.proto",
	}, impl)
}

func (g *grpcService) EnterPartyQueue(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	return g.enterPartyQueue(ctx, req)
}

func (g *grpcService) CancelPartyQueue(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	return g.cancelPartyQueue(ctx, req)
}

func (g *grpcService) GetPartyQueueStatus(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	return g.getPartyQueueStatus(ctx, req)
}

func (g *grpcService) CreateManualRoomBattle(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	return g.createManualRoomBattle(ctx, req)
}

func (g *grpcService) CommitAssignmentReady(ctx context.Context, req *structpb.Struct) (*structpb.Struct, error) {
	return g.commitAssignmentReady(ctx, req)
}

func (g *grpcService) wrap(methodName string, handler handlerFunc) grpc.MethodHandler {
	return func(_ any, ctx context.Context, dec func(any) error, interceptor grpc.UnaryServerInterceptor) (any, error) {
		req := &structpb.Struct{}
		if err := dec(req); err != nil {
			return nil, err
		}
		if interceptor == nil {
			return handler(ctx, req)
		}
		info := &grpc.UnaryServerInfo{
			Server:     g,
			FullMethod: fmt.Sprintf("/%s/%s", RoomControlServiceName, methodName),
		}
		return interceptor(ctx, req, info, func(innerCtx context.Context, innerReq any) (any, error) {
			casted, ok := innerReq.(*structpb.Struct)
			if !ok {
				return nil, fmt.Errorf("invalid request type: %T", innerReq)
			}
			return handler(innerCtx, casted)
		})
	}
}

func ListenAndServe(addr string, service *RoomControlService) (*grpc.Server, net.Listener, error) {
	grpcServer := grpc.NewServer()
	RegisterRoomControlService(grpcServer, service)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, nil, err
	}
	go func() {
		_ = grpcServer.Serve(ln)
	}()
	return grpcServer, ln, nil
}
