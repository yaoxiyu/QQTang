# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services/account_service

COPY services/account_service/go.mod services/account_service/go.sum ./
RUN go mod download

COPY services/account_service/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/account_service ./cmd/account_service

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata wget \
    && addgroup -S app \
    && adduser -S -G app app

WORKDIR /app
COPY --from=builder /out/account_service /app/account_service

ENV ACCOUNT_HTTP_LISTEN_ADDR=0.0.0.0:18080
ENV ACCOUNT_POSTGRES_DSN=postgres://qqtang:qqtang_dev_pass@account_postgres:5432/qqtang_account_dev?sslmode=disable
ENV ACCOUNT_ACCESS_TOKEN_TTL_SECONDS=900
ENV ACCOUNT_REFRESH_TOKEN_TTL_SECONDS=1209600
ENV ACCOUNT_ROOM_TICKET_TTL_SECONDS=60
ENV ACCOUNT_BATTLE_TICKET_TTL_SECONDS=60
ENV ACCOUNT_TOKEN_SIGN_SECRET=dev_account_token_secret
ENV ACCOUNT_ROOM_TICKET_SIGN_SECRET=dev_room_ticket_secret
ENV ACCOUNT_GAME_SERVICE_BASE_URL=http://game_service:18081
ENV ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID=primary
ENV ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET=dev_internal_shared_secret
ENV ACCOUNT_ALLOW_MULTI_DEVICE=false
ENV ACCOUNT_LOG_SQL=false
ENV SERVICE_HEALTH_PORT=18080

EXPOSE 18080

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/account_service"]
