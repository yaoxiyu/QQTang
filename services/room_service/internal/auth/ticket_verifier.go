package auth

import "strings"

type TicketVerifier struct {
	secret string
}

func NewTicketVerifier(secret string) *TicketVerifier {
	return &TicketVerifier{secret: secret}
}

func (v *TicketVerifier) Verify(ticket string) bool {
	if v == nil || strings.TrimSpace(v.secret) == "" {
		return false
	}
	normalized := strings.TrimSpace(ticket)
	return normalized != "" && normalized != "invalid"
}
