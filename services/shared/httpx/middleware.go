package httpx

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
)

type contextKey string

const (
	CorrelationIDHeader = "X-Correlation-Id"
	RequestIDHeader     = "X-Request-Id"
	ctxCorrelationID    contextKey = "correlation_id"
	ctxRequestID        contextKey = "request_id"
)

// CorrelationIDFromContext returns the correlation ID stored in ctx, or empty string.
func CorrelationIDFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(ctxCorrelationID).(string); ok {
		return v
	}
	return ""
}

// RequestIDFromContext returns the request ID stored in ctx, or empty string.
func RequestIDFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(ctxRequestID).(string); ok {
		return v
	}
	return ""
}

// WithCorrelationID stores the correlation ID (from header or newly generated) in context.
func WithCorrelationID(r *http.Request) *http.Request {
	cid := r.Header.Get(CorrelationIDHeader)
	if cid == "" {
		cid = r.Header.Get("X-Request-Id")
	}
	if cid == "" {
		cid = generateID()
	}
	ctx := context.WithValue(r.Context(), ctxCorrelationID, cid)
	ctx = context.WithValue(ctx, ctxRequestID, generateID())
	return r.WithContext(ctx)
}

// SetCorrelationHeaders writes correlation and request ID headers to the response.
func SetCorrelationHeaders(w http.ResponseWriter, r *http.Request) {
	if cid := CorrelationIDFromContext(r.Context()); cid != "" {
		w.Header().Set(CorrelationIDHeader, cid)
	}
	if rid := RequestIDFromContext(r.Context()); rid != "" {
		w.Header().Set(RequestIDHeader, rid)
	}
}

func generateID() string {
	buf := make([]byte, 12)
	if _, err := rand.Read(buf); err != nil {
		return ""
	}
	return hex.EncodeToString(buf)
}
