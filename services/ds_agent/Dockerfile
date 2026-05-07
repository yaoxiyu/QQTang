# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src/services

COPY services/ds_agent/go.mod ds_agent/
COPY services/shared/httpx/go.mod shared/httpx/
COPY services/shared/internalauth/go.mod shared/internalauth/
RUN cd ds_agent && go mod download

COPY services/shared/httpx/ shared/httpx/
COPY services/shared/internalauth/ shared/internalauth/
COPY services/ds_agent/ ds_agent/
RUN cd ds_agent && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/ds_agent ./cmd/ds_agent

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata wget libstdc++6 libgcc-s1 libicu74 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /out/ds_agent /app/ds_agent
COPY build/docker/battle_ds/qqtang_battle_ds.x86_64 /app/qqtang_battle_ds.x86_64
COPY build/docker/battle_ds/qqtang_battle_ds.pck /app/qqtang_battle_ds.pck
COPY build/docker/battle_ds/data_QQTang_linuxbsd_x86_64 /app/data_QQTang_linuxbsd_x86_64
COPY addons/qqt_native/qqt_native.gdextension /app/addons/qqt_native/qqt_native.gdextension
COPY build/docker/battle_ds/qqt_native.linux.template_release.x86_64.so /app/external/qqt_native/bin/qqt_native.linux.template_release.x86_64.so
USER root
RUN chmod +x /app/qqtang_battle_ds.x86_64 \
    && chown -R app:app /app

ENV DS_AGENT_HTTP_ADDR=0.0.0.0:19090
ENV DS_AGENT_INTERNAL_AUTH_KEY_ID=primary
# Secrets must be injected at deployment time.
ENV DS_AGENT_INTERNAL_AUTH_SHARED_SECRET=
ENV DS_AGENT_INTERNAL_AUTH_MAX_SKEW_SECONDS=60
ENV DS_BATTLE_PORT=9000
ENV DS_GODOT_EXECUTABLE=/app/qqtang_battle_ds.x86_64
ENV DS_PROJECT_ROOT=
ENV DS_BATTLE_SCENE_PATH=
ENV SERVICE_HEALTH_PORT=19090

EXPOSE 19090/tcp
EXPOSE 9000/udp

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz" >/dev/null || exit 1

USER app
ENTRYPOINT ["/app/ds_agent"]
