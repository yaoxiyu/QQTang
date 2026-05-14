package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"
)

func TestTicketVerifierRejectsForgedSignature(t *testing.T) {
	verifier := NewTicketVerifier("room-secret")
	claims := validClaims("join", "room-1")
	ticket := issueTicket(t, "wrong-secret", claims)

	_, err := verifier.VerifyWithExpected(ticket, ExpectedRoomTicket{
		Purpose:   "join",
		RoomID:    "room-1",
		AccountID: claims.AccountID,
		ProfileID: claims.ProfileID,
	})
	if err == nil {
		t.Fatalf("expected forged signature to be rejected")
	}
}

func TestTicketVerifierRejectsExpiredTicket(t *testing.T) {
	verifier := NewTicketVerifier("room-secret")
	claims := validClaims("join", "room-1")
	now := time.Now().UTC()
	claims.IssuedAtUnixSec = now.Add(-3 * time.Minute).Unix()
	claims.ExpireAtUnixSec = now.Add(-2 * time.Minute).Unix()
	ticket := issueTicket(t, "room-secret", claims)

	_, err := verifier.VerifyWithExpected(ticket, ExpectedRoomTicket{
		Purpose:   "join",
		RoomID:    "room-1",
		AccountID: claims.AccountID,
		ProfileID: claims.ProfileID,
	})
	if err != ErrTicketExpired {
		t.Fatalf("expected ErrTicketExpired, got %v", err)
	}
}

func TestTicketVerifierRejectsWrongPurpose(t *testing.T) {
	verifier := NewTicketVerifier("room-secret")
	claims := validClaims("join", "room-1")
	ticket := issueTicket(t, "room-secret", claims)

	_, err := verifier.VerifyWithExpected(ticket, ExpectedRoomTicket{
		Purpose:   "create",
		AccountID: claims.AccountID,
		ProfileID: claims.ProfileID,
	})
	if err != ErrTicketPurposeMismatch {
		t.Fatalf("expected ErrTicketPurposeMismatch, got %v", err)
	}
}

func TestTicketVerifierRejectsWrongRoom(t *testing.T) {
	verifier := NewTicketVerifier("room-secret")
	claims := validClaims("join", "room-1")
	ticket := issueTicket(t, "room-secret", claims)

	_, err := verifier.VerifyWithExpected(ticket, ExpectedRoomTicket{
		Purpose:   "join",
		RoomID:    "room-2",
		AccountID: claims.AccountID,
		ProfileID: claims.ProfileID,
	})
	if err != ErrTicketRoomMismatch {
		t.Fatalf("expected ErrTicketRoomMismatch, got %v", err)
	}
}

func TestTicketVerifierAcceptsLegalTicket(t *testing.T) {
	verifier := NewTicketVerifier("room-secret")
	claims := validClaims("join", "room-1")
	ticket := issueTicket(t, "room-secret", claims)

	decoded, err := verifier.VerifyWithExpected(ticket, ExpectedRoomTicket{
		Purpose:   "join",
		RoomID:    "room-1",
		AccountID: claims.AccountID,
		ProfileID: claims.ProfileID,
		TicketID:  claims.TicketID,
	})
	if err != nil {
		t.Fatalf("expected legal ticket to pass: %v", err)
	}
	if decoded.TicketID != claims.TicketID {
		t.Fatalf("unexpected ticket_id: got=%s want=%s", decoded.TicketID, claims.TicketID)
	}
}

func validClaims(purpose string, roomID string) RoomTicketClaims {
	now := time.Now().UTC()
	return RoomTicketClaims{
		TicketID:        "ticket-1",
		AccountID:       "acc-1",
		ProfileID:       "pro-1",
		DeviceSessionID: "dsess-1",
		Purpose:         purpose,
		RoomID:          roomID,
		RoomKind:        "private_room",
		IssuedAtUnixSec: now.Unix(),
		ExpireAtUnixSec: now.Add(2 * time.Minute).Unix(),
		Nonce:           "nonce-1",
	}
}

func issueTicket(t *testing.T, secret string, claims RoomTicketClaims) string {
	t.Helper()
	claims.Signature = ""
	payload, err := json.Marshal(claims)
	if err != nil {
		t.Fatalf("marshal claims: %v", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(payload)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(encoded))
	signature := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return encoded + "." + signature
}
