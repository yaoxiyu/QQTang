# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services

COPY services/game_service/go.mod services/game_service/go.sum game_service/
COPY services/shared/contentmanifest/go.mod shared/contentmanifest/
RUN cd game_service && go mod download

COPY services/shared/contentmanifest/ shared/contentmanifest/
COPY services/game_service/ game_service/
RUN cd game_service && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/game_service ./cmd/game_service

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata wget \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /out/game_service /app/game_service
COPY build/generated/room_manifest/room_manifest.json /app/build/generated/room_manifest/room_manifest.json

ENV GAME_HTTP_ADDR=0.0.0.0:18081
ENV GAME_GRPC_ADDR=0.0.0.0:19081
ENV GAME_POSTGRES_DSN=postgres://qqtang_game:qqtang_game_dev_pass@game_postgres:5432/qqtang_game_dev?sslmode=disable
ENV GAME_ROOM_MANIFEST_PATH=/app/build/generated/room_manifest/room_manifest.json
ENV GAME_JWT_SHARED_SECRET=dev_game_jwt_shared_secret
ENV GAME_INTERNAL_AUTH_KEY_ID=primary
ENV GAME_INTERNAL_AUTH_SHARED_SECRET=dev_internal_shared_secret
ENV GAME_DEFAULT_DS_HOST=ds_manager_service
ENV GAME_DEFAULT_DS_PORT=19010
ENV GAME_DS_MANAGER_URL=http://ds_manager_service:18090
ENV GAME_LOG_SQL=false
ENV SERVICE_HEALTH_PORT=18081

EXPOSE 18081 19081

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/game_service"]
