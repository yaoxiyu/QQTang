package ticket

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"qqtang/services/account_service/internal/profile"
	"qqtang/services/account_service/internal/storage"
)

var (
	ErrPurposeInvalid              = errors.New("ROOM_TICKET_PURPOSE_INVALID")
	ErrTargetInvalid               = errors.New("ROOM_TICKET_TARGET_INVALID")
	ErrRequestedMatchInvalid       = errors.New("ROOM_TICKET_REQUESTED_MATCH_INVALID")
	ErrLoadoutNotOwned             = errors.New("ROOM_TICKET_LOADOUT_NOT_OWNED")
	ErrMatchmadeAssignmentRequired = errors.New("ROOM_TICKET_MATCHMADE_ASSIGNMENT_REQUIRED")
)

type Service struct {
	profileService *profile.Service
	ticketRepo     *storage.TicketRepository
	issuer         *RoomTicketIssuer
	grantClient    *AssignmentGrantClient
	ttl            time.Duration
}

type CreateTicketInput struct {
	AccountID               string
	DeviceSessionID         string
	Purpose                 string `json:"purpose"`
	RoomID                  string `json:"room_id"`
	RoomKind                string `json:"room_kind"`
	RequestedMatchID        string `json:"requested_match_id"`
	AssignmentID            string `json:"assignment_id"`
	SelectedCharacterID     string `json:"selected_character_id"`
	SelectedCharacterSkinID string `json:"selected_character_skin_id"`
	SelectedBubbleStyleID   string `json:"selected_bubble_style_id"`
	SelectedBubbleSkinID    string `json:"selected_bubble_skin_id"`
}

type CreateTicketResult struct {
	Ticket                  string   `json:"ticket"`
	TicketID                string   `json:"ticket_id"`
	AccountID               string   `json:"account_id"`
	ProfileID               string   `json:"profile_id"`
	DeviceSessionID         string   `json:"device_session_id"`
	Purpose                 string   `json:"purpose"`
	RoomID                  string   `json:"room_id"`
	RoomKind                string   `json:"room_kind"`
	RequestedMatchID        string   `json:"requested_match_id"`
	AssignmentID            string   `json:"assignment_id"`
	MatchSource             string   `json:"match_source"`
	SeasonID                string   `json:"season_id"`
	LockedMapID             string   `json:"locked_map_id"`
	LockedRuleSetID         string   `json:"locked_rule_set_id"`
	LockedModeID            string   `json:"locked_mode_id"`
	AssignedTeamID          int      `json:"assigned_team_id"`
	ExpectedMemberCount     int      `json:"expected_member_count"`
	AutoReadyOnJoin         bool     `json:"auto_ready_on_join"`
	HiddenRoom              bool     `json:"hidden_room"`
	DisplayName             string   `json:"display_name"`
	AllowedCharacterIDs     []string `json:"allowed_character_ids"`
	AllowedCharacterSkinIDs []string `json:"allowed_character_skin_ids"`
	AllowedBubbleStyleIDs   []string `json:"allowed_bubble_style_ids"`
	AllowedBubbleSkinIDs    []string `json:"allowed_bubble_skin_ids"`
	IssuedAtUnixSec         int64    `json:"issued_at_unix_sec"`
	ExpireAtUnixSec         int64    `json:"expire_at_unix_sec"`
}

func NewService(profileService *profile.Service, ticketRepo *storage.TicketRepository, issuer *RoomTicketIssuer, grantClient *AssignmentGrantClient, ttl time.Duration) *Service {
	return &Service{
		profileService: profileService,
		ticketRepo:     ticketRepo,
		issuer:         issuer,
		grantClient:    grantClient,
		ttl:            ttl,
	}
}

func (s *Service) CreateTicket(ctx context.Context, input CreateTicketInput) (CreateTicketResult, error) {
	if input.Purpose != "create" && input.Purpose != "join" && input.Purpose != "resume" {
		return CreateTicketResult{}, ErrPurposeInvalid
	}
	profileResp, err := s.profileService.GetMyProfile(ctx, input.AccountID)
	if err != nil {
		return CreateTicketResult{}, err
	}
	if !contains(profileResp.OwnedCharacterIDs, input.SelectedCharacterID) ||
		!contains(profileResp.OwnedCharacterSkinIDs, input.SelectedCharacterSkinID) ||
		!contains(profileResp.OwnedBubbleStyleIDs, input.SelectedBubbleStyleID) ||
		!contains(profileResp.OwnedBubbleSkinIDs, input.SelectedBubbleSkinID) {
		return CreateTicketResult{}, ErrLoadoutNotOwned
	}

	lockedClaim := AssignmentGrantResult{}
	if input.RoomKind == "matchmade_room" {
		if strings.TrimSpace(input.AssignmentID) == "" {
			return CreateTicketResult{}, ErrMatchmadeAssignmentRequired
		}
		if s.grantClient == nil {
			return CreateTicketResult{}, ErrAssignmentGrantFailed
		}
		grant, err := s.grantClient.GetGrant(ctx, input.AssignmentID, profileResp.AccountID, profileResp.ProfileID, input.RoomKind)
		if err != nil {
			return CreateTicketResult{}, err
		}
		if grant.TicketRole != input.Purpose {
			return CreateTicketResult{}, ErrAssignmentGrantForbidden
		}
		lockedClaim = grant
		input.RoomID = grant.RoomID
		input.RoomKind = grant.RoomKind
		input.RequestedMatchID = grant.MatchID
	}
	if input.Purpose == "create" {
		if strings.TrimSpace(input.RoomKind) == "" {
			return CreateTicketResult{}, ErrTargetInvalid
		}
	} else if strings.TrimSpace(input.RoomID) == "" {
		return CreateTicketResult{}, ErrTargetInvalid
	}

	now := time.Now().UTC()
	expireAt := now.Add(s.ttl)
	ticketID, err := s.issuer.NewOpaqueID("ticket")
	if err != nil {
		return CreateTicketResult{}, err
	}
	nonce, err := s.issuer.NewNonce()
	if err != nil {
		return CreateTicketResult{}, err
	}
	claim := RoomTicketClaim{
		TicketID:                ticketID,
		AccountID:               profileResp.AccountID,
		ProfileID:               profileResp.ProfileID,
		DeviceSessionID:         input.DeviceSessionID,
		Purpose:                 input.Purpose,
		RoomID:                  input.RoomID,
		RoomKind:                input.RoomKind,
		RequestedMatchID:        input.RequestedMatchID,
		AssignmentID:            input.AssignmentID,
		AssignmentRevision:      lockedClaim.AssignmentRevision,
		MatchSource:             lockedClaim.MatchSource,
		SeasonID:                lockedClaim.SeasonID,
		LockedMapID:             lockedClaim.LockedMapID,
		LockedRuleSetID:         lockedClaim.LockedRuleSetID,
		LockedModeID:            lockedClaim.LockedModeID,
		AssignedTeamID:          lockedClaim.AssignedTeamID,
		ExpectedMemberCount:     lockedClaim.ExpectedMemberCount,
		AutoReadyOnJoin:         lockedClaim.AutoReadyOnJoin,
		HiddenRoom:              lockedClaim.HiddenRoom,
		DisplayName:             profileResp.Nickname,
		AllowedCharacterIDs:     profileResp.OwnedCharacterIDs,
		AllowedCharacterSkinIDs: profileResp.OwnedCharacterSkinIDs,
		AllowedBubbleStyleIDs:   profileResp.OwnedBubbleStyleIDs,
		AllowedBubbleSkinIDs:    profileResp.OwnedBubbleSkinIDs,
		IssuedAtUnixSec:         now.Unix(),
		ExpireAtUnixSec:         expireAt.Unix(),
		Nonce:                   nonce,
	}
	token, signedClaim, err := s.issuer.IssueTicket(claim)
	if err != nil {
		return CreateTicketResult{}, err
	}
	claimsJSON, err := json.Marshal(signedClaim)
	if err != nil {
		return CreateTicketResult{}, err
	}
	if err := s.ticketRepo.Create(ctx, storage.RoomEntryTicketRecord{
		TicketID:         ticketID,
		AccountID:        profileResp.AccountID,
		ProfileID:        profileResp.ProfileID,
		DeviceSessionID:  input.DeviceSessionID,
		RoomID:           toNullString(input.RoomID),
		RoomKind:         toNullString(input.RoomKind),
		Purpose:          input.Purpose,
		RequestedMatchID: toNullString(input.RequestedMatchID),
		ClaimsJSON:       claimsJSON,
		IssuedAt:         now,
		ExpireAt:         expireAt,
	}); err != nil {
		return CreateTicketResult{}, err
	}
	return CreateTicketResult{
		Ticket:                  token,
		TicketID:                ticketID,
		AccountID:               profileResp.AccountID,
		ProfileID:               profileResp.ProfileID,
		DeviceSessionID:         input.DeviceSessionID,
		Purpose:                 input.Purpose,
		RoomID:                  input.RoomID,
		RoomKind:                input.RoomKind,
		RequestedMatchID:        input.RequestedMatchID,
		AssignmentID:            input.AssignmentID,
		MatchSource:             lockedClaim.MatchSource,
		SeasonID:                lockedClaim.SeasonID,
		LockedMapID:             lockedClaim.LockedMapID,
		LockedRuleSetID:         lockedClaim.LockedRuleSetID,
		LockedModeID:            lockedClaim.LockedModeID,
		AssignedTeamID:          lockedClaim.AssignedTeamID,
		ExpectedMemberCount:     lockedClaim.ExpectedMemberCount,
		AutoReadyOnJoin:         lockedClaim.AutoReadyOnJoin,
		HiddenRoom:              lockedClaim.HiddenRoom,
		DisplayName:             profileResp.Nickname,
		AllowedCharacterIDs:     profileResp.OwnedCharacterIDs,
		AllowedCharacterSkinIDs: profileResp.OwnedCharacterSkinIDs,
		AllowedBubbleStyleIDs:   profileResp.OwnedBubbleStyleIDs,
		AllowedBubbleSkinIDs:    profileResp.OwnedBubbleSkinIDs,
		IssuedAtUnixSec:         now.Unix(),
		ExpireAtUnixSec:         expireAt.Unix(),
	}, nil
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func toNullString(value string) sql.NullString {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return sql.NullString{}
	}
	return sql.NullString{String: trimmed, Valid: true}
}
