package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

type TicketVerifier struct {
	secret []byte
}

type ExpectedRoomTicket struct {
	Purpose   string
	RoomID    string
	RoomKind  string
	AccountID string
	ProfileID string
	TicketID  string
}

type RoomTicketClaims struct {
	TicketID        string `json:"ticket_id"`
	AccountID       string `json:"account_id"`
	ProfileID       string `json:"profile_id"`
	DeviceSessionID string `json:"device_session_id"`
	Purpose         string `json:"purpose"`
	RoomID          string `json:"room_id"`
	RoomKind        string `json:"room_kind"`
	IssuedAtUnixSec int64  `json:"issued_at_unix_sec"`
	ExpireAtUnixSec int64  `json:"expire_at_unix_sec"`
	Nonce           string `json:"nonce"`
	Signature       string `json:"signature,omitempty"`
}

var (
	ErrTicketVerifierNotReady = errors.New("ticket verifier not ready")
	ErrTicketFormatInvalid    = errors.New("ticket format invalid")
	ErrTicketPayloadInvalid   = errors.New("ticket payload invalid")
	ErrTicketSignatureInvalid = errors.New("ticket signature invalid")
	ErrTicketExpired          = errors.New("ticket expired")
	ErrTicketClaimsInvalid    = errors.New("ticket claims invalid")
	ErrTicketPurposeMismatch  = errors.New("ticket purpose mismatch")
	ErrTicketRoomMismatch     = errors.New("ticket room mismatch")
	ErrTicketRoomKindMismatch = errors.New("ticket room kind mismatch")
	ErrTicketAccountMismatch  = errors.New("ticket account mismatch")
	ErrTicketProfileMismatch  = errors.New("ticket profile mismatch")
	ErrTicketIDMismatch       = errors.New("ticket id mismatch")
)

func NewTicketVerifier(secret string) *TicketVerifier {
	return &TicketVerifier{secret: []byte(secret)}
}

func (v *TicketVerifier) VerifyWithExpected(ticket string, expected ExpectedRoomTicket) (RoomTicketClaims, error) {
	if v == nil || len(v.secret) == 0 || strings.TrimSpace(string(v.secret)) == "" {
		return RoomTicketClaims{}, ErrTicketVerifierNotReady
	}

	normalized := strings.TrimSpace(ticket)
	if normalized == "" {
		return RoomTicketClaims{}, ErrTicketFormatInvalid
	}

	parts := strings.Split(normalized, ".")
	if len(parts) != 2 {
		return RoomTicketClaims{}, ErrTicketFormatInvalid
	}
	encodedPayload := strings.TrimSpace(parts[0])
	providedSignature := strings.TrimSpace(parts[1])
	if encodedPayload == "" || providedSignature == "" {
		return RoomTicketClaims{}, ErrTicketFormatInvalid
	}

	expectedSignature := v.sign(encodedPayload)
	if subtle.ConstantTimeCompare([]byte(expectedSignature), []byte(providedSignature)) != 1 {
		return RoomTicketClaims{}, ErrTicketSignatureInvalid
	}

	payload, err := base64.RawURLEncoding.DecodeString(encodedPayload)
	if err != nil {
		return RoomTicketClaims{}, ErrTicketPayloadInvalid
	}

	var claims RoomTicketClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return RoomTicketClaims{}, ErrTicketPayloadInvalid
	}
	claims.Signature = providedSignature
	if err := validateClaims(claims, expected); err != nil {
		return RoomTicketClaims{}, err
	}
	return claims, nil
}

func (v *TicketVerifier) sign(value string) string {
	mac := hmac.New(sha256.New, v.secret)
	_, _ = mac.Write([]byte(value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func validateClaims(claims RoomTicketClaims, expected ExpectedRoomTicket) error {
	purpose := strings.TrimSpace(claims.Purpose)
	if strings.TrimSpace(claims.TicketID) == "" ||
		strings.TrimSpace(claims.AccountID) == "" ||
		strings.TrimSpace(claims.ProfileID) == "" ||
		strings.TrimSpace(claims.DeviceSessionID) == "" ||
		purpose == "" {
		return ErrTicketClaimsInvalid
	}

	switch purpose {
	case "create", "join", "resume":
	default:
		return ErrTicketPurposeMismatch
	}

	nowUnix := time.Now().UTC().Unix()
	if claims.ExpireAtUnixSec <= nowUnix {
		return ErrTicketExpired
	}

	if expected.Purpose != "" && purpose != strings.TrimSpace(expected.Purpose) {
		return ErrTicketPurposeMismatch
	}
	if expected.RoomID != "" && strings.TrimSpace(claims.RoomID) != strings.TrimSpace(expected.RoomID) {
		return ErrTicketRoomMismatch
	}
	if expected.RoomKind != "" && strings.TrimSpace(claims.RoomKind) != strings.TrimSpace(expected.RoomKind) {
		return ErrTicketRoomKindMismatch
	}
	if expected.AccountID != "" && strings.TrimSpace(claims.AccountID) != strings.TrimSpace(expected.AccountID) {
		return ErrTicketAccountMismatch
	}
	if expected.ProfileID != "" && strings.TrimSpace(claims.ProfileID) != strings.TrimSpace(expected.ProfileID) {
		return ErrTicketProfileMismatch
	}
	if expected.TicketID != "" && strings.TrimSpace(claims.TicketID) != strings.TrimSpace(expected.TicketID) {
		return ErrTicketIDMismatch
	}

	return nil
}
