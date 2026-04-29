package internalhttp

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"strconv"
	"time"
)

const (
	HeaderKeyID      = "X-Internal-Key-Id"
	HeaderTimestamp  = "X-Internal-Timestamp"
	HeaderNonce      = "X-Internal-Nonce"
	HeaderBodySHA256 = "X-Internal-Body-SHA256"
	HeaderSignature  = "X-Internal-Signature"
)

func SignRequest(req *http.Request, keyID string, sharedSecret string, body []byte, now time.Time) error {
	if req == nil || keyID == "" || sharedSecret == "" {
		return fmt.Errorf("internal request signing requires request, key id, and shared secret")
	}
	nonce, err := randomNonce()
	if err != nil {
		return err
	}
	timestamp := strconv.FormatInt(now.UTC().Unix(), 10)
	bodyHash := BodySHA256Hex(body)
	signature := Sign(req.Method, req.URL.RequestURI(), timestamp, nonce, bodyHash, sharedSecret)

	req.Header.Set(HeaderKeyID, keyID)
	req.Header.Set(HeaderTimestamp, timestamp)
	req.Header.Set(HeaderNonce, nonce)
	req.Header.Set(HeaderBodySHA256, bodyHash)
	req.Header.Set(HeaderSignature, signature)
	return nil
}

func BodySHA256Hex(body []byte) string {
	sum := sha256.Sum256(body)
	return hex.EncodeToString(sum[:])
}

func Sign(method string, pathAndQuery string, timestamp string, nonce string, bodyHash string, sharedSecret string) string {
	mac := hmac.New(sha256.New, []byte(sharedSecret))
	_, _ = mac.Write([]byte(method + "\n" + pathAndQuery + "\n" + timestamp + "\n" + nonce + "\n" + bodyHash))
	return hex.EncodeToString(mac.Sum(nil))
}

func randomNonce() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
