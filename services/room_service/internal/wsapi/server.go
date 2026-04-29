package wsapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"

	roomv1 "qqtang/services/room_service/internal/gen/qqt/room/v1"
	"qqtang/services/room_service/internal/roomapp"
)

type Server struct {
	addr            string
	listenAddr      string
	logger          *slog.Logger
	dispatcher      *Dispatcher
	upgrader        websocket.Upgrader
	httpSrv         *http.Server
	started         atomic.Bool
	connSeq         atomic.Int64
	mu              sync.Mutex
	connMu          sync.RWMutex
	conns           map[string]*Connection
	originSet       map[string]struct{}
	allowAllOrigins bool
	bgCtx           context.Context
	bgCancel        context.CancelFunc
	bgWait          sync.WaitGroup
}

func NewServer(addr string, app *roomapp.Service, logger *slog.Logger, allowedOrigins ...string) *Server {
	originSet := make(map[string]struct{}, len(allowedOrigins))
	for _, origin := range allowedOrigins {
		normalized := strings.TrimSpace(origin)
		if normalized == "" {
			continue
		}
		originSet[normalized] = struct{}{}
	}
	allowAllOrigins := len(originSet) == 0
	s := &Server{
		addr:            addr,
		logger:          logger,
		dispatcher:      NewDispatcher(app),
		conns:           map[string]*Connection{},
		originSet:       originSet,
		allowAllOrigins: allowAllOrigins,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  4096,
			WriteBufferSize: 4096,
			CheckOrigin: func(r *http.Request) bool {
				return isOriginAllowed(r, allowAllOrigins, originSet)
			},
		},
	}
	s.dispatcher.SetLogger(logger)
	s.dispatcher.SetDirectorySnapshotProvider(s.buildDirectorySnapshot)
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
	s.bgCtx, s.bgCancel = context.WithCancel(context.Background())

	go func() {
		if err := s.httpSrv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
			s.logger.Error("ws server stopped with error", "error", err)
			s.started.Store(false)
		}
	}()
	s.startBackgroundWorkers()
	s.logger.Info("room ws server listening", "addr", s.listenAddr)
	return nil
}

func (s *Server) Shutdown(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.started.Store(false)
	if s.bgCancel != nil {
		s.bgCancel()
		s.bgCancel = nil
	}
	s.bgWait.Wait()
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
	s.registerConnection(conn)
	defer s.unregisterConnection(conn.ID())
	defer s.onConnectionClosed(conn)
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

		previousRoomID := conn.BoundRoomID()
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
		if isDirectoryAffectingPayload(env.PayloadType) && hasOperationAccepted(outbound) {
			s.broadcastDirectorySnapshot("")
		}
		if isRoomSnapshotAffectingPayload(env.PayloadType) && hasOperationAccepted(outbound) {
			s.broadcastLatestRoomSnapshot(conn, previousRoomID)
		}
	}
}

func (s *Server) registerConnection(conn *Connection) {
	if conn == nil {
		return
	}
	s.connMu.Lock()
	defer s.connMu.Unlock()
	s.conns[conn.ID()] = conn
}

func (s *Server) unregisterConnection(connID string) {
	s.connMu.Lock()
	defer s.connMu.Unlock()
	delete(s.conns, connID)
}

func (s *Server) onConnectionClosed(conn *Connection) {
	if conn == nil || s.dispatcher == nil || s.dispatcher.app == nil {
		return
	}
	roomID := conn.BoundRoomID()
	memberID := conn.BoundMemberID()
	if roomID == "" || memberID == "" {
		s.dispatcher.app.SetDirectorySubscribed(conn.ID(), false)
		conn.SetDirectorySubscribed(false)
		conn.ClearRoomBinding()
		return
	}

	snapshot, err := s.dispatcher.app.MarkDisconnected(roomID, memberID)
	if err == nil && snapshot != nil {
		s.broadcastRoomSnapshot(roomID, snapshot)
	}

	s.dispatcher.app.SetDirectorySubscribed(conn.ID(), false)
	conn.SetDirectorySubscribed(false)
	conn.ClearRoomBinding()
}

func (s *Server) broadcastRoomSnapshot(roomID string, snapshot *roomapp.SnapshotProjection) {
	if roomID == "" || snapshot == nil {
		return
	}
	targets := s.roomConnections(roomID)
	for _, conn := range targets {
		_ = conn.SendBinary(EncodeSnapshotPush(conn, "", snapshot))
	}
}

func (s *Server) broadcastLatestRoomSnapshot(source *Connection, fallbackRoomID string) {
	if s == nil || s.dispatcher == nil || s.dispatcher.app == nil {
		return
	}
	roomID := ""
	sourceID := ""
	if source != nil {
		roomID = source.BoundRoomID()
		sourceID = source.ID()
	}
	if roomID == "" {
		roomID = fallbackRoomID
	}
	if roomID == "" {
		return
	}
	snapshot, err := s.dispatcher.app.SnapshotProjection(roomID)
	if err != nil || snapshot == nil {
		return
	}
	s.broadcastRoomSnapshotExcept(roomID, snapshot, sourceID)
}

func (s *Server) broadcastRoomSnapshotExcept(roomID string, snapshot *roomapp.SnapshotProjection, excludedConnID string) {
	if roomID == "" || snapshot == nil {
		return
	}
	targets := s.roomConnections(roomID)
	for _, conn := range targets {
		if conn == nil || conn.ID() == excludedConnID {
			continue
		}
		_ = conn.SendBinary(EncodeSnapshotPush(conn, "", snapshot))
	}
}

func (s *Server) roomConnections(roomID string) []*Connection {
	s.connMu.RLock()
	defer s.connMu.RUnlock()
	result := make([]*Connection, 0, len(s.conns))
	for _, conn := range s.conns {
		if conn != nil && conn.BoundRoomID() == roomID {
			result = append(result, conn)
		}
	}
	return result
}

func (s *Server) buildDirectorySnapshot() *roomv1.RoomDirectorySnapshot {
	if s == nil || s.dispatcher == nil || s.dispatcher.app == nil {
		return &roomv1.RoomDirectorySnapshot{}
	}
	host, port := splitHostPort(s.listenAddr)
	return s.dispatcher.app.DirectorySnapshot(host, port)
}

func (s *Server) broadcastDirectorySnapshot(requestID string) {
	if s == nil {
		return
	}
	snapshot := s.buildDirectorySnapshot()
	for _, connID := range s.dispatcher.app.DirectorySubscriberIDs() {
		conn := s.connectionByID(connID)
		if conn == nil {
			continue
		}
		_ = conn.SendBinary(EncodeDirectorySnapshotPush(conn, requestID, snapshot))
	}
}

func (s *Server) connectionByID(connID string) *Connection {
	s.connMu.RLock()
	defer s.connMu.RUnlock()
	return s.conns[connID]
}

func splitHostPort(addr string) (string, int32) {
	if addr == "" {
		return "", 0
	}
	host, rawPort, err := net.SplitHostPort(addr)
	if err != nil {
		return "", 0
	}
	port, err := strconv.Atoi(rawPort)
	if err != nil {
		return host, 0
	}
	return host, int32(port)
}

func isDirectoryAffectingPayload(payloadType PayloadType) bool {
	switch payloadType {
	case PayloadCreateRoom,
		PayloadJoinRoom,
		PayloadLeaveRoom,
		PayloadUpdateSelection,
		PayloadUpdateMatchRoomConfig,
		PayloadStartManualRoomBattle,
		PayloadAckBattleEntry,
		PayloadEnterMatchQueue,
		PayloadCancelMatchQueue:
		return true
	default:
		return false
	}
}

func isRoomSnapshotAffectingPayload(payloadType PayloadType) bool {
	switch payloadType {
	case PayloadCreateRoom,
		PayloadJoinRoom,
		PayloadResumeRoom,
		PayloadUpdateProfile,
		PayloadUpdateSelection,
		PayloadUpdateMatchRoomConfig,
		PayloadToggleReady,
		PayloadLeaveRoom,
		PayloadStartManualRoomBattle,
		PayloadEnterMatchQueue,
		PayloadCancelMatchQueue,
		PayloadAckBattleEntry:
		return true
	default:
		return false
	}
}

func hasOperationAccepted(messages [][]byte) bool {
	for _, message := range messages {
		if len(message) == 0 {
			continue
		}
		env := &roomv1.ServerEnvelope{}
		if err := proto.Unmarshal(message, env); err != nil {
			continue
		}
		if env.GetOperationAccepted() != nil {
			return true
		}
	}
	return false
}

func (s *Server) startBackgroundWorkers() {
	if s == nil || s.bgCtx == nil {
		return
	}
	s.bgWait.Add(1)
	go func() {
		defer s.bgWait.Done()
		ticker := time.NewTicker(400 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-s.bgCtx.Done():
				return
			case <-ticker.C:
				s.syncControlPlaneSnapshots()
			}
		}
	}()
}

func (s *Server) syncControlPlaneSnapshots() {
	if s == nil || s.dispatcher == nil || s.dispatcher.app == nil {
		return
	}
	updates := s.dispatcher.app.SyncMatchQueueStatus()
	updates = append(updates, s.dispatcher.app.SyncBattleAssignmentStatus()...)
	s.dispatcher.app.SweepEmptyBattleRooms(time.Now())
	for _, update := range updates {
		if update.Snapshot == nil || update.RoomID == "" {
			continue
		}
		s.broadcastRoomSnapshot(update.RoomID, update.Snapshot)
	}
}

func isOriginAllowed(r *http.Request, allowAll bool, originSet map[string]struct{}) bool {
	if allowAll {
		return true
	}
	if r == nil {
		return false
	}
	origin := strings.TrimSpace(r.Header.Get("Origin"))
	if origin == "" {
		return false
	}
	_, ok := originSet[origin]
	return ok
}
