package ticket

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
)

type RoomTicketIssuer struct {
	secret []byte
}

func NewRoomTicketIssuer(secret string) *RoomTicketIssuer {
	return &RoomTicketIssuer{secret: []byte(secret)}
}

func (i *RoomTicketIssuer) IssueTicket(claim RoomTicketClaim) (string, RoomTicketClaim, error) {
	claim.Signature = ""
	payload, err := json.Marshal(claim)
	if err != nil {
		return "", RoomTicketClaim{}, err
	}
	encoded := base64.RawURLEncoding.EncodeToString(payload)
	signature := i.sign(encoded)
	claim.Signature = signature
	return encoded + "." + signature, claim, nil
}

func (i *RoomTicketIssuer) NewOpaqueID(prefix string) (string, error) {
	raw := make([]byte, 16)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return prefix + "_" + hex.EncodeToString(raw), nil
}

func (i *RoomTicketIssuer) NewNonce() (string, error) {
	raw := make([]byte, 16)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return hex.EncodeToString(raw), nil
}

func (i *RoomTicketIssuer) sign(value string) string {
	mac := hmac.New(sha256.New, i.secret)
	_, _ = mac.Write([]byte(value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
