package wsapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"

	"qqtang/services/room_service/internal/roomapp"
)

type Server struct {
	addr       string
	listenAddr string
	logger     *slog.Logger
	dispatcher *Dispatcher
	upgrader   websocket.Upgrader
	httpSrv    *http.Server
	started    atomic.Bool
	connSeq    atomic.Int64
	mu         sync.Mutex
}

func NewServer(addr string, app *roomapp.Service, logger *slog.Logger) *Server {
	s := &Server{
		addr:       addr,
		logger:     logger,
		dispatcher: NewDispatcher(app),
		upgrader: websocket.Upgrader{
			ReadBufferSize:  4096,
			WriteBufferSize: 4096,
			CheckOrigin: func(_ *http.Request) bool {
				return true
			},
		},
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", s.handleWS)
	s.httpSrv = &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	return s
}

func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	ln, err := net.Listen("tcp", s.addr)
	if err != nil {
		return fmt.Errorf("listen ws: %w", err)
	}
	s.listenAddr = ln.Addr().String()
	s.started.Store(true)

	go func() {
		if err := s.httpSrv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
			s.logger.Error("ws server stopped with error", "error", err)
			s.started.Store(false)
		}
	}()
	s.logger.Info("room ws server listening", "addr", s.listenAddr)
	return nil
}

func (s *Server) Shutdown(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.started.Store(false)
	if s.httpSrv == nil {
		return nil
	}
	return s.httpSrv.Shutdown(ctx)
}

func (s *Server) Ready() bool {
	return s != nil && s.started.Load()
}

func (s *Server) Addr() string {
	return s.listenAddr
}

func (s *Server) handleWS(w http.ResponseWriter, r *http.Request) {
	if !s.Ready() {
		http.Error(w, "ws server not ready", http.StatusServiceUnavailable)
		return
	}
	socket, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	conn := newConnection(fmt.Sprintf("conn-%d", s.connSeq.Add(1)), socket)
	defer socket.Close()

	for {
		msgType, payload, err := socket.ReadMessage()
		if err != nil {
			return
		}
		if msgType != websocket.BinaryMessage {
			_ = conn.SendBinary(EncodeOperationRejected(conn, "", "Unknown", "OPERATION_REJECTED", "binary protobuf frame required"))
			continue
		}

		env, err := DecodeClientEnvelope(payload)
		if err != nil {
			_ = conn.SendBinary(EncodeOperationRejected(conn, "", "Decode", "OPERATION_REJECTED", err.Error()))
			continue
		}

		outbound, err := s.dispatcher.Dispatch(conn, env)
		if err != nil {
			_ = conn.SendBinary(EncodeOperationRejected(conn, env.RequestID, "Dispatch", "OPERATION_REJECTED", err.Error()))
			continue
		}
		for _, message := range outbound {
			if sendErr := conn.SendBinary(message); sendErr != nil {
				return
			}
		}
	}
}
