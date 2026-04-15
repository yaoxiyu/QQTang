// internal_curl — sends an HMAC-signed request to a game_service internal endpoint.
//
// Usage:
//
//	go run ./tools/internal_curl -method POST -url http://127.0.0.1:18081/internal/v1/battles/manual-room/create -body '{"source_room_id":"room_test",...}'
//	go run ./tools/internal_curl -method GET  -url http://127.0.0.1:18081/internal/v1/assignments/some_id/grant?account_id=a&profile_id=p
package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

func main() {
	method := flag.String("method", "POST", "HTTP method")
	rawURL := flag.String("url", "", "Full URL including query string")
	body := flag.String("body", "", "Request body (JSON)")
	keyID := flag.String("key-id", "primary", "X-Internal-Key-Id")
	secret := flag.String("secret", "dev_internal_shared_secret", "HMAC shared secret")
	flag.Parse()

	if *rawURL == "" {
		fmt.Fprintln(os.Stderr, "usage: internal_curl -url <URL> [-method POST] [-body '{}'] [-secret s]")
		os.Exit(1)
	}

	parsed, err := url.Parse(*rawURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bad url: %v\n", err)
		os.Exit(1)
	}
	pathAndQuery := parsed.RequestURI()

	bodyBytes := []byte(*body)
	bodyHash := sha256Hex(bodyBytes)
	nonce := randomHex(16)
	timestamp := strconv.FormatInt(time.Now().UTC().Unix(), 10)

	canonical := strings.Join([]string{*method, pathAndQuery, timestamp, nonce, bodyHash}, "\n")
	mac := hmac.New(sha256.New, []byte(*secret))
	mac.Write([]byte(canonical))
	signature := hex.EncodeToString(mac.Sum(nil))

	var bodyReader io.Reader
	if len(bodyBytes) > 0 {
		bodyReader = strings.NewReader(*body)
	}
	req, err := http.NewRequest(*method, *rawURL, bodyReader)
	if err != nil {
		fmt.Fprintf(os.Stderr, "request error: %v\n", err)
		os.Exit(1)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Key-Id", *keyID)
	req.Header.Set("X-Internal-Timestamp", timestamp)
	req.Header.Set("X-Internal-Nonce", nonce)
	req.Header.Set("X-Internal-Body-SHA256", bodyHash)
	req.Header.Set("X-Internal-Signature", signature)

	fmt.Fprintf(os.Stderr, ">>> %s %s\n", *method, pathAndQuery)
	fmt.Fprintf(os.Stderr, "    Key-Id:    %s\n", *keyID)
	fmt.Fprintf(os.Stderr, "    Timestamp: %s\n", timestamp)
	fmt.Fprintf(os.Stderr, "    Nonce:     %s\n", nonce)
	fmt.Fprintf(os.Stderr, "    BodyHash:  %s\n", bodyHash)
	fmt.Fprintf(os.Stderr, "    Signature: %s\n", signature)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "request failed: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	fmt.Fprintf(os.Stderr, "<<< %d %s\n", resp.StatusCode, resp.Status)
	io.Copy(os.Stdout, resp.Body)
	fmt.Println()
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func randomHex(n int) string {
	buf := make([]byte, n)
	rand.Read(buf)
	return hex.EncodeToString(buf)
}
