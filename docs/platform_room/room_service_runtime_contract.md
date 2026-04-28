# Room Service Runtime Contract

## Scope
This document defines the formal runtime contract of Current Room Service.

## Formal Identity
- Service entrypoint (formal room authority only): `services/room_service/cmd/room_service/main.go`
- Runtime language: Go.
- Protocol: WebSocket binary frames with protobuf wire payloads.
- Default listen port: `9100`
- Default room endpoint port: `9100` (`ROOM_WS_ADDR`, default `127.0.0.1:9100`).
- Health endpoints:
  - `/healthz`
  - `/readyz`

## Required Config
- `ROOM_HTTP_ADDR`
- `ROOM_WS_ADDR`
- `ROOM_ENV`
- `ROOM_ALLOWED_ORIGINS`
- `ROOM_TICKET_SECRET`
- `ROOM_MANIFEST_PATH`
- `ROOM_GAME_SERVICE_GRPC_ADDR`
- `ROOM_INSTANCE_ID`
- `ROOM_SHARD_ID`
- `ROOM_LOG_LEVEL`

## Runtime Architecture
```text
cmd/room_service/main.go
  -> internal/config
  -> internal/manifest (load room_manifest.json)
  -> internal/registry
  -> internal/roomapp (in-memory room authority)
  -> internal/wsapi (ws + protobuf gateway)
  -> internal/gameclient (grpc control-plane client)
```

## Responsibilities
- Verify room tickets for create/join/resume operations.
- Validate loadout and selection legality from room manifest.
- Maintain room aggregate state in memory.
- Support:
  - create room
  - join room
  - resume room
  - leave room
  - update profile
  - update selection
  - toggle ready
  - update match room config
  - enter match queue
  - cancel match queue
  - start manual room battle
  - ack battle entry
- Push room snapshot with `snapshot_revision`.
- Push room directory snapshot for subscribers.
- Push `BattleEntryReady` events when assignment transitions to ready.
- Reject invalid requests with operation-level error payload.

## Security And Boundary Rules
- WebSocket `CheckOrigin` must enforce `ROOM_ALLOWED_ORIGINS` in production mode.
- Development mode can use relaxed origin policy for local workflows.
- Room snapshot and canonical projections must not expose reconnect token fields.
- Room service to game service path must use generated typed gRPC client and typed protobuf payloads only.

## Not In Scope
- Battle runtime execution.
- Battle input authority.
- Battle scene orchestration in Godot runtime.

## Legacy Compatibility
- Legacy room server paths were removed in Current and must not be reintroduced.
- Formal Room Service authority is no longer `res://scenes/network/room_service_scene.tscn`.

