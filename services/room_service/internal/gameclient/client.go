package gameclient

import (
	"context"
	"fmt"
	"sync"
	"time"

	gamev1 "qqtang/services/room_service/internal/gen/qqt/gamev1shim"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
)

const defaultRPCTimeout = 3 * time.Second

type Client struct {
	addr       string
	rpcTimeout time.Duration

	mu   sync.Mutex
	conn *grpc.ClientConn
	stub gamev1.RoomControlServiceClient
}

func New(addr string) *Client {
	return &Client{
		addr:       addr,
		rpcTimeout: defaultRPCTimeout,
	}
}

func (c *Client) Addr() string {
	if c == nil {
		return ""
	}
	return c.addr
}

func (c *Client) Close() error {
	if c == nil {
		return nil
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.conn == nil {
		return nil
	}
	err := c.conn.Close()
	c.conn = nil
	c.stub = nil
	return err
}

func (c *Client) EnterPartyQueue(input EnterPartyQueueInput) (EnterPartyQueueResult, error) {
	if input.RoomID == "" {
		return EnterPartyQueueResult{}, fmt.Errorf("room_id is required")
	}
	response, err := c.callEnterPartyQueue(input)
	if err != nil {
		return EnterPartyQueueResult{}, err
	}
	return fromPBEnterPartyQueue(response), nil
}

func (c *Client) CancelPartyQueue(input CancelPartyQueueInput) (CancelPartyQueueResult, error) {
	if input.RoomID == "" {
		return CancelPartyQueueResult{}, fmt.Errorf("room_id is required")
	}
	if input.QueueEntryID == "" {
		return CancelPartyQueueResult{}, fmt.Errorf("queue_entry_id is required")
	}
	response, err := c.callCancelPartyQueue(input)
	if err != nil {
		return CancelPartyQueueResult{}, err
	}
	return fromPBCancelPartyQueue(response), nil
}

func (c *Client) GetPartyQueueStatus(input GetPartyQueueStatusInput) (GetPartyQueueStatusResult, error) {
	if input.RoomID == "" {
		return GetPartyQueueStatusResult{}, fmt.Errorf("room_id is required")
	}
	if input.QueueEntryID == "" {
		return GetPartyQueueStatusResult{}, fmt.Errorf("queue_entry_id is required")
	}
	response, err := c.callGetPartyQueueStatus(input)
	if err != nil {
		return GetPartyQueueStatusResult{}, err
	}
	return fromPBGetPartyQueueStatus(response), nil
}

func (c *Client) CreateManualRoomBattle(input CreateManualRoomBattleInput) (CreateManualRoomBattleResult, error) {
	if input.RoomID == "" {
		return CreateManualRoomBattleResult{}, fmt.Errorf("room_id is required")
	}
	response, err := c.callCreateManualRoomBattle(input)
	if err != nil {
		return CreateManualRoomBattleResult{}, err
	}
	return fromPBCreateManualRoomBattle(response), nil
}

func (c *Client) GetBattleAssignmentStatus(input GetBattleAssignmentStatusInput) (GetBattleAssignmentStatusResult, error) {
	if input.RoomID == "" {
		return GetBattleAssignmentStatusResult{}, fmt.Errorf("room_id is required")
	}
	if input.AssignmentID == "" {
		return GetBattleAssignmentStatusResult{}, fmt.Errorf("assignment_id is required")
	}
	response, err := c.callGetBattleAssignmentStatus(input)
	if err != nil {
		return GetBattleAssignmentStatusResult{}, err
	}
	return fromPBGetBattleAssignmentStatus(response), nil
}

func (c *Client) CommitAssignmentReady(input CommitAssignmentReadyInput) (CommitAssignmentReadyResult, error) {
	if input.RoomID == "" {
		return CommitAssignmentReadyResult{}, fmt.Errorf("room_id is required")
	}
	if input.AssignmentID == "" {
		return CommitAssignmentReadyResult{}, fmt.Errorf("assignment_id is required")
	}
	response, err := c.callCommitAssignmentReady(input)
	if err != nil {
		return CommitAssignmentReadyResult{}, err
	}
	return fromPBCommitAssignmentReady(response), nil
}

func (c *Client) callEnterPartyQueue(input EnterPartyQueueInput) (*gamev1.EnterPartyQueueResponse, error) {
	stub, err := c.stubClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	response, rpcErr := stub.EnterPartyQueue(ctx, &gamev1.EnterPartyQueueRequest{
		Context:         toPBRoomContext(input.RoomID, input.RoomKind),
		QueueType:       input.QueueType,
		MatchFormatId:   input.MatchFormatID,
		SelectedModeIds: append([]string{}, input.SelectedModeIDs...),
		Members:         toPBPartyMembers(input.Members),
	})
	if rpcErr != nil {
		return nil, mapRPCError("EnterPartyQueue", rpcErr)
	}
	return response, nil
}

func (c *Client) callCancelPartyQueue(input CancelPartyQueueInput) (*gamev1.CancelPartyQueueResponse, error) {
	stub, err := c.stubClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	response, rpcErr := stub.CancelPartyQueue(ctx, &gamev1.CancelPartyQueueRequest{
		Context:      toPBRoomContext(input.RoomID, input.RoomKind),
		QueueEntryId: input.QueueEntryID,
	})
	if rpcErr != nil {
		return nil, mapRPCError("CancelPartyQueue", rpcErr)
	}
	return response, nil
}

func (c *Client) callGetPartyQueueStatus(input GetPartyQueueStatusInput) (*gamev1.GetPartyQueueStatusResponse, error) {
	stub, err := c.stubClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	response, rpcErr := stub.GetPartyQueueStatus(ctx, &gamev1.GetPartyQueueStatusRequest{
		Context:      toPBRoomContext(input.RoomID, input.RoomKind),
		QueueEntryId: input.QueueEntryID,
	})
	if rpcErr != nil {
		return nil, mapRPCError("GetPartyQueueStatus", rpcErr)
	}
	return response, nil
}

func (c *Client) callCreateManualRoomBattle(input CreateManualRoomBattleInput) (*gamev1.CreateManualRoomBattleResponse, error) {
	stub, err := c.stubClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	response, rpcErr := stub.CreateManualRoomBattle(ctx, &gamev1.CreateManualRoomBattleRequest{
		Context:   toPBRoomContext(input.RoomID, input.RoomKind),
		ModeId:    input.ModeID,
		RuleSetId: input.RuleSetID,
		MapId:     input.MapID,
		Members:   toPBPartyMembers(input.Members),
	})
	if rpcErr != nil {
		return nil, mapRPCError("CreateManualRoomBattle", rpcErr)
	}
	return response, nil
}

func (c *Client) callGetBattleAssignmentStatus(input GetBattleAssignmentStatusInput) (*gamev1.GetBattleAssignmentStatusResponse, error) {
	stub, err := c.stubClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	response, rpcErr := stub.GetBattleAssignmentStatus(ctx, &gamev1.GetBattleAssignmentStatusRequest{
		RoomId:        input.RoomID,
		RoomKind:      input.RoomKind,
		AssignmentId:  input.AssignmentID,
		KnownRevision: input.KnownRevision,
	})
	if rpcErr != nil {
		return nil, mapRPCError("GetBattleAssignmentStatus", rpcErr)
	}
	return response, nil
}

func (c *Client) callCommitAssignmentReady(input CommitAssignmentReadyInput) (*gamev1.CommitAssignmentReadyResponse, error) {
	stub, err := c.stubClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	response, rpcErr := stub.CommitAssignmentReady(ctx, &gamev1.CommitAssignmentReadyRequest{
		Context:            toPBRoomContext(input.RoomID, input.RoomKind),
		AssignmentId:       input.AssignmentID,
		MatchId:            input.MatchID,
		BattleId:           input.BattleID,
		AccountId:          input.AccountID,
		ProfileId:          input.ProfileID,
		AssignmentRevision: int32(input.AssignmentRevision),
	})
	if rpcErr != nil {
		return nil, mapRPCError("CommitAssignmentReady", rpcErr)
	}
	return response, nil
}

func (c *Client) stubClient() (gamev1.RoomControlServiceClient, error) {
	if c == nil {
		return nil, fmt.Errorf("game client is nil")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.stub != nil {
		return c.stub, nil
	}
	if c.addr == "" {
		return nil, fmt.Errorf("game service grpc addr is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.rpcTimeout)
	defer cancel()
	conn, err := grpc.DialContext(
		ctx,
		c.addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		return nil, mapRPCError("Dial", err)
	}
	c.conn = conn
	c.stub = gamev1.NewRoomControlServiceClient(conn)
	return c.stub, nil
}

func mapRPCError(operation string, err error) error {
	if err == nil {
		return nil
	}
	st, ok := status.FromError(err)
	if !ok {
		return fmt.Errorf("game rpc %s failed: %w", operation, err)
	}
	switch st.Code() {
	case codes.DeadlineExceeded:
		return fmt.Errorf("game rpc %s timeout: %s", operation, st.Message())
	case codes.Unavailable:
		return fmt.Errorf("game rpc %s unavailable: %s", operation, st.Message())
	default:
		return fmt.Errorf("game rpc %s failed (%s): %s", operation, st.Code().String(), st.Message())
	}
}
