# Network Control Plane

## Purpose
Define control-plane boundaries among `account_service`, `game_service`, `ds_manager_service`, `room_service`, client, and battle DS.

## Service Responsibilities
- `account_service`
  - Authentication, profile, room-entry ticket, battle-entry ticket.
  - No battle process orchestration.
- `game_service`
  - Matchmaking, party queue, assignment lifecycle, manual room battle allocation.
  - Exposes internal HTTP APIs and internal gRPC room-control APIs.
- `ds_manager_service`
  - Battle DS process lifecycle and port allocation only.
  - Internal API: allocate, ready, active, reap.
- `room_service` (Go)
  - Room create/join/resume/leave/profile/selection/ready state authority.
  - Match room config update and queue lifecycle state authority.
  - Manual battle start and assignment ack state writeback authority.
  - Room snapshot push and room directory over WebSocket protobuf.
  - Calls `game_service` through generated typed internal gRPC room-control client.

## Protocol Boundaries
- Client to `room_service`: WebSocket binary + protobuf envelope.
- `room_service` to `game_service`: internal gRPC room-control RPC.
- `game_service` to `ds_manager_service`: internal HTTP with internal auth signature.
- Client to `account_service` and `game_service`: public HTTP APIs.

## gRPC Contract Rules
- Contract source:
  - `proto/qqt/internal/game/v1/room_control.proto`
- Server registration in `game_service` must use generated service registration, not manual `grpc.ServiceDesc`.
- Request and response path must stay typed protobuf messages.
- `structpb.Struct` is forbidden as formal room-control payload path.
- Mapping between protobuf and domain models must stay in `services/game_service/internal/rpcapi/mapper.go`.

## Internal Auth
- Internal HTTP APIs use shared internal auth signing.
- No unauthenticated internal endpoint path is allowed.
- Callers and servers must share one signing contract.

## Consistency Rules
- Local DB transactions protect local state only.
- External side effects must have explicit state transitions and retry strategy.
- Allocation/queue failures must leave observable state (`pending`, `failed`, `cancelled`, `expired`).
