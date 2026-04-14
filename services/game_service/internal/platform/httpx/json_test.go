package httpx

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDecodeJSONBodyRejectsInvalidInputs(t *testing.T) {
	tests := []struct {
		name string
		body []byte
	}{
		{name: "invalid json", body: []byte(`{"name":`)},
		{name: "unknown field", body: []byte(`{"name":"ok","extra":true}`)},
		{name: "empty body", body: nil},
		{name: "trailing garbage", body: []byte(`{"name":"ok"} true`)},
		{name: "too large", body: append([]byte(`{"name":"`), append(bytes.Repeat([]byte("a"), maxRequestBodyBytes), []byte(`"}`)...)...)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/test", bytes.NewReader(tt.body))
			resp := httptest.NewRecorder()
			var payload struct {
				Name string `json:"name"`
			}
			if err := DecodeJSONBody(resp, req, &payload); err == nil {
				t.Fatal("expected decode error")
			}
		})
	}
}

func TestDecodeJSONBodyAcceptsValidInput(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/test", bytes.NewReader([]byte(`{"name":"ok"}`)))
	resp := httptest.NewRecorder()
	var payload struct {
		Name string `json:"name"`
	}
	if err := DecodeJSONBody(resp, req, &payload); err != nil {
		t.Fatalf("DecodeJSONBody returned error: %v", err)
	}
	if payload.Name != "ok" {
		t.Fatalf("expected decoded name ok, got %q", payload.Name)
	}
}
