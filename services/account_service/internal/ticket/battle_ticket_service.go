package ticket

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"qqtang/services/account_service/internal/profile"
	"qqtang/services/account_service/internal/storage"
)

var (
	ErrBattleTicketMissingFields = errors.New("BATTLE_TICKET_MISSING_FIELDS")
	ErrBattleTicketGrantFailed   = errors.New("BATTLE_TICKET_GRANT_FAILED")
)

type BattleTicketService struct {
	profileService   *profile.Service
	ticketRepo       *storage.TicketRepository
	issuer           *RoomTicketIssuer
	battleGrantClient *BattleAssignmentGrantClient
	ttl              time.Duration
}

type CreateBattleTicketInput struct {
	AccountID       string `json:"-"`
	DeviceSessionID string `json:"-"`
	AssignmentID    string `json:"assignment_id"`
	BattleID        string `json:"battle_id"`
}

type CreateBattleTicketResult struct {
	Ticket              string `json:"ticket"`
	TicketID            string `json:"ticket_id"`
	AccountID           string `json:"account_id"`
	ProfileID           string `json:"profile_id"`
	DeviceSessionID     string `json:"device_session_id"`
	AssignmentID        string `json:"assignment_id"`
	BattleID            string `json:"battle_id"`
	MatchID             string `json:"match_id"`
	MapID               string `json:"map_id"`
	RuleSetID           string `json:"rule_set_id"`
	ModeID              string `json:"mode_id"`
	AssignedTeamID      int    `json:"assigned_team_id"`
	ExpectedMemberCount int    `json:"expected_member_count"`
	BattleServerHost    string `json:"battle_server_host"`
	BattleServerPort    int    `json:"battle_server_port"`
	IssuedAtUnixSec     int64  `json:"issued_at_unix_sec"`
	ExpireAtUnixSec     int64  `json:"expire_at_unix_sec"`
}

func NewBattleTicketService(profileService *profile.Service, ticketRepo *storage.TicketRepository, issuer *RoomTicketIssuer, battleGrantClient *BattleAssignmentGrantClient, ttl time.Duration) *BattleTicketService {
	return &BattleTicketService{
		profileService:    profileService,
		ticketRepo:        ticketRepo,
		issuer:            issuer,
		battleGrantClient: battleGrantClient,
		ttl:               ttl,
	}
}

func (s *BattleTicketService) CreateBattleTicket(ctx context.Context, input CreateBattleTicketInput) (CreateBattleTicketResult, error) {
	if strings.TrimSpace(input.AssignmentID) == "" || strings.TrimSpace(input.BattleID) == "" {
		return CreateBattleTicketResult{}, ErrBattleTicketMissingFields
	}

	profileResp, err := s.profileService.GetMyProfile(ctx, input.AccountID)
	if err != nil {
		return CreateBattleTicketResult{}, err
	}

	if s.battleGrantClient == nil {
		return CreateBattleTicketResult{}, ErrBattleTicketGrantFailed
	}
	grant, err := s.battleGrantClient.GetGrant(ctx, input.AssignmentID, input.BattleID, profileResp.AccountID, profileResp.ProfileID)
	if err != nil {
		return CreateBattleTicketResult{}, err
	}

	now := time.Now().UTC()
	expireAt := now.Add(s.ttl)
	ticketID, err := s.issuer.NewOpaqueID("bticket")
	if err != nil {
		return CreateBattleTicketResult{}, err
	}
	nonce, err := s.issuer.NewNonce()
	if err != nil {
		return CreateBattleTicketResult{}, err
	}

	claim := RoomTicketClaim{
		TicketID:            ticketID,
		AccountID:           profileResp.AccountID,
		ProfileID:           profileResp.ProfileID,
		DeviceSessionID:     input.DeviceSessionID,
		Purpose:             "battle_entry",
		RoomID:              "",
		RoomKind:            "",
		RequestedMatchID:    grant.MatchID,
		AssignmentID:        input.AssignmentID,
		LockedMapID:         grant.MapID,
		LockedRuleSetID:     grant.RuleSetID,
		LockedModeID:        grant.ModeID,
		AssignedTeamID:      grant.AssignedTeamID,
		ExpectedMemberCount: grant.ExpectedMemberCount,
		DisplayName:         profileResp.Nickname,
		IssuedAtUnixSec:     now.Unix(),
		ExpireAtUnixSec:     expireAt.Unix(),
		Nonce:               nonce,
	}

	token, _, err := s.issuer.IssueTicket(claim)
	if err != nil {
		return CreateBattleTicketResult{}, err
	}

	claimsJSON, err := json.Marshal(claim)
	if err != nil {
		return CreateBattleTicketResult{}, err
	}

	if err := s.ticketRepo.Create(ctx, storage.RoomEntryTicketRecord{
		TicketID:        ticketID,
		AccountID:       profileResp.AccountID,
		ProfileID:       profileResp.ProfileID,
		DeviceSessionID: input.DeviceSessionID,
		Purpose:         "battle_entry",
		ClaimsJSON:      claimsJSON,
		IssuedAt:        now,
		ExpireAt:        expireAt,
	}); err != nil {
		return CreateBattleTicketResult{}, err
	}

	return CreateBattleTicketResult{
		Ticket:              token,
		TicketID:            ticketID,
		AccountID:           profileResp.AccountID,
		ProfileID:           profileResp.ProfileID,
		DeviceSessionID:     input.DeviceSessionID,
		AssignmentID:        input.AssignmentID,
		BattleID:            input.BattleID,
		MatchID:             grant.MatchID,
		MapID:               grant.MapID,
		RuleSetID:           grant.RuleSetID,
		ModeID:              grant.ModeID,
		AssignedTeamID:      grant.AssignedTeamID,
		ExpectedMemberCount: grant.ExpectedMemberCount,
		BattleServerHost:    grant.BattleServerHost,
		BattleServerPort:    grant.BattleServerPort,
		IssuedAtUnixSec:     now.Unix(),
		ExpireAtUnixSec:     expireAt.Unix(),
	}, nil
}

// CanConsumeBattleTicket checks if a ticket purpose is battle_entry (for battle_ds validation)
func CanConsumeBattleTicket(purpose string) bool {
	return purpose == "battle_entry"
}

// IsRoomOnlyTicket checks if a ticket should be consumed only by room_service
func IsRoomOnlyTicket(purpose string) bool {
	return purpose == "create" || purpose == "join" || purpose == "resume"
}

var _ error = ErrBattleTicketMissingFields
