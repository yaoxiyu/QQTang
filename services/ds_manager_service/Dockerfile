# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services/ds_manager_service

COPY services/ds_manager_service/go.mod ./
RUN go mod download

COPY services/ds_manager_service/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/ds_manager_service ./cmd/ds_manager_service

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata wget \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /out/ds_manager_service /app/ds_manager_service

ENV DSM_HTTP_ADDR=0.0.0.0:18090
ENV DSM_INTERNAL_AUTH_KEY_ID=primary
ENV DSM_INTERNAL_AUTH_SHARED_SECRET=dev_internal_shared_secret
ENV DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS=60
ENV DSM_BATTLE_LOG_DIR=/tmp/qqt_battle_logs
ENV DSM_PORT_RANGE_START=19010
ENV DSM_PORT_RANGE_END=19050
ENV DSM_READY_TIMEOUT_SEC=15
ENV DSM_IDLE_REAP_TIMEOUT_SEC=300
ENV DSM_POOL_MODE=local_process_legacy
ENV DSM_POOL_MIN_READY=1
ENV DSM_POOL_MAX_SIZE=4
ENV DSM_POOL_PREFILL_BATCH=1
ENV DSM_POOL_RECONCILE_INTERVAL_SEC=5
ENV DSM_ALLOCATE_WAIT_READY_TIMEOUT_MS=5000
ENV DSM_DOCKER_SOCKET=unix:///var/run/docker.sock
ENV DSM_DS_IMAGE=qqtang/battle-ds:dev
ENV DSM_DS_CONTAINER_PREFIX=qqt-ds
ENV DSM_DS_AGENT_PORT=19090
ENV DSM_DS_BATTLE_PORT=9000
ENV DSM_DS_ADVERTISE_MODE=container_name
ENV SERVICE_HEALTH_PORT=18090

EXPOSE 18090

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/ds_manager_service"]
