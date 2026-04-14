package internalhttp

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
)

const (
	HeaderKeyID      = "X-Internal-Key-Id"
	HeaderTimestamp  = "X-Internal-Timestamp"
	HeaderNonce      = "X-Internal-Nonce"
	HeaderBodySHA256 = "X-Internal-Body-SHA256"
	HeaderSignature  = "X-Internal-Signature"
)

func BodySHA256Hex(body []byte) string {
	sum := sha256.Sum256(body)
	return hex.EncodeToString(sum[:])
}

func Sign(method string, pathAndQuery string, timestamp string, nonce string, bodyHash string, sharedSecret string) string {
	mac := hmac.New(sha256.New, []byte(sharedSecret))
	_, _ = mac.Write([]byte(canonicalString(method, pathAndQuery, timestamp, nonce, bodyHash)))
	return hex.EncodeToString(mac.Sum(nil))
}

func SignatureEqual(a string, b string) bool {
	return hmac.Equal([]byte(a), []byte(b))
}

func canonicalString(method string, pathAndQuery string, timestamp string, nonce string, bodyHash string) string {
	return method + "\n" + pathAndQuery + "\n" + timestamp + "\n" + nonce + "\n" + bodyHash
}
