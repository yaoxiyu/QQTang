# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services/ds_manager_service

COPY services/ds_manager_service/go.mod ./
RUN go mod download

COPY services/ds_manager_service/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/ds_manager_service ./cmd/ds_manager_service

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata wget \
    && addgroup -S app \
    && adduser -S -G app app

WORKDIR /app
COPY --from=builder /out/ds_manager_service /app/ds_manager_service

ENV DSM_HTTP_ADDR=0.0.0.0:18090
ENV DSM_INTERNAL_AUTH_KEY_ID=primary
ENV DSM_INTERNAL_AUTH_SHARED_SECRET=dev_internal_shared_secret
ENV DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS=60
ENV DSM_GODOT_EXECUTABLE=godot4
ENV DSM_PROJECT_ROOT=/workspace
ENV DSM_BATTLE_SCENE_PATH=res://scenes/network/dedicated_server_scene.tscn
ENV DSM_BATTLE_TICKET_SECRET=dev_battle_ticket_secret
ENV DSM_BATTLE_LOG_DIR=/tmp/qqt_battle_logs
ENV DSM_DS_HOST=127.0.0.1
ENV DSM_PORT_RANGE_START=19010
ENV DSM_PORT_RANGE_END=19050
ENV DSM_READY_TIMEOUT_SEC=15
ENV DSM_IDLE_REAP_TIMEOUT_SEC=300
ENV SERVICE_HEALTH_PORT=18090

EXPOSE 18090

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/ds_manager_service"]
