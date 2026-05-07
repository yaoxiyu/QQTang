# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services

COPY services/room_service/go.mod services/room_service/go.sum room_service/
COPY services/shared/contentmanifest/go.mod shared/contentmanifest/
COPY services/shared/internalauth/go.mod shared/internalauth/
RUN cd room_service && go mod download

COPY services/shared/contentmanifest/ shared/contentmanifest/
COPY services/shared/internalauth/ shared/internalauth/
COPY services/room_service/ room_service/
RUN cd room_service && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/room_service ./cmd/room_service

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata wget \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /out/room_service /app/room_service
COPY build/generated/room_manifest/room_manifest.json /app/build/generated/room_manifest/room_manifest.json

ENV ROOM_HTTP_ADDR=0.0.0.0:19100
ENV ROOM_WS_ADDR=0.0.0.0:9100
ENV ROOM_DEFAULT_PORT=9100
# Secrets must be injected at deployment time.
ENV ROOM_TICKET_SECRET=
ENV ROOM_MANIFEST_PATH=/app/build/generated/room_manifest/room_manifest.json
ENV ROOM_GAME_SERVICE_GRPC_ADDR=game_service:19081
ENV ROOM_LOG_LEVEL=info
ENV ROOM_SHARD_ID=room-shard-dev-01
ENV ROOM_INSTANCE_ID=room-instance-dev-01
ENV SERVICE_HEALTH_PORT=19100

EXPOSE 19100 9100

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/room_service"]
