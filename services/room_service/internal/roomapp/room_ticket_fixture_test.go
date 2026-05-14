package roomapp

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"qqtang/services/room_service/internal/auth"
)

const testRoomTicketSecret = "test-secret"

func mustIssueCreateRoomTicket(t *testing.T, roomKind, accountID, profileID string) string {
	t.Helper()
	return mustIssueRoomTicket(t, auth.RoomTicketClaims{
		TicketID:        fmt.Sprintf("ticket-create-%d", time.Now().UnixNano()),
		AccountID:       accountID,
		ProfileID:       profileID,
		DeviceSessionID: "dsess-test",
		Purpose:         "create",
		RoomKind:        roomKind,
		IssuedAtUnixSec: time.Now().UTC().Unix(),
		ExpireAtUnixSec: time.Now().UTC().Add(5 * time.Minute).Unix(),
		Nonce:           "nonce-create",
	})
}

func mustIssueJoinRoomTicket(t *testing.T, roomID, accountID, profileID string) string {
	t.Helper()
	return mustIssueRoomTicket(t, auth.RoomTicketClaims{
		TicketID:        fmt.Sprintf("ticket-join-%d", time.Now().UnixNano()),
		AccountID:       accountID,
		ProfileID:       profileID,
		DeviceSessionID: "dsess-test",
		Purpose:         "join",
		RoomID:          roomID,
		IssuedAtUnixSec: time.Now().UTC().Unix(),
		ExpireAtUnixSec: time.Now().UTC().Add(5 * time.Minute).Unix(),
		Nonce:           "nonce-join",
	})
}

func mustIssueResumeRoomTicket(t *testing.T, roomID string) string {
	t.Helper()
	return mustIssueRoomTicket(t, auth.RoomTicketClaims{
		TicketID:        fmt.Sprintf("ticket-resume-%d", time.Now().UnixNano()),
		AccountID:       "acc-resume",
		ProfileID:       "pro-resume",
		DeviceSessionID: "dsess-test",
		Purpose:         "resume",
		RoomID:          roomID,
		IssuedAtUnixSec: time.Now().UTC().Unix(),
		ExpireAtUnixSec: time.Now().UTC().Add(5 * time.Minute).Unix(),
		Nonce:           "nonce-resume",
	})
}

func mustIssueRoomTicket(t *testing.T, claim auth.RoomTicketClaims) string {
	t.Helper()
	claim.Signature = ""
	payload, err := json.Marshal(claim)
	if err != nil {
		t.Fatalf("marshal test ticket claim: %v", err)
	}
	encodedPayload := base64.RawURLEncoding.EncodeToString(payload)
	mac := hmac.New(sha256.New, []byte(testRoomTicketSecret))
	_, _ = mac.Write([]byte(encodedPayload))
	signature := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return encodedPayload + "." + signature
}
