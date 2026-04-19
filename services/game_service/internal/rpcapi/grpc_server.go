package rpcapi

import (
	"net"

	gamev1 "qqtang/services/game_service/internal/gen/qqt/gamev1shim"

	"google.golang.org/grpc"
)

func RegisterRoomControlService(server *grpc.Server, service *RoomControlService) {
	gamev1.RegisterRoomControlServiceServer(server, service)
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
