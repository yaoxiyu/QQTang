# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services

COPY services/account_service/go.mod services/account_service/go.sum account_service/
COPY services/shared/httpx/go.mod shared/httpx/
COPY services/shared/internalauth/go.mod shared/internalauth/
RUN cd account_service && go mod download

COPY services/shared/httpx/ shared/httpx/
COPY services/shared/internalauth/ shared/internalauth/
COPY services/account_service/ account_service/
RUN cd account_service && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/account_service ./cmd/account_service

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata wget \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /out/account_service /app/account_service

ENV ACCOUNT_HTTP_LISTEN_ADDR=0.0.0.0:18080
ENV ACCOUNT_ACCESS_TOKEN_TTL_SECONDS=900
ENV ACCOUNT_REFRESH_TOKEN_TTL_SECONDS=1209600
ENV ACCOUNT_ROOM_TICKET_TTL_SECONDS=60
ENV ACCOUNT_BATTLE_TICKET_TTL_SECONDS=60
ENV ACCOUNT_GAME_SERVICE_BASE_URL=http://game_service:18081
ENV ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID=primary
# Secrets and DSN must be injected at deployment time.
ENV ACCOUNT_POSTGRES_DSN=
ENV ACCOUNT_TOKEN_SIGN_SECRET=
ENV ACCOUNT_ROOM_TICKET_SIGN_SECRET=
ENV ACCOUNT_BATTLE_TICKET_SIGN_SECRET=
ENV ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET=
ENV ACCOUNT_ALLOW_MULTI_DEVICE=false
ENV ACCOUNT_LOG_SQL=false
ENV SERVICE_HEALTH_PORT=18080

EXPOSE 18080

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/account_service"]
