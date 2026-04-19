# Phase24 Migration Worklog

## Step 0
- Date: 2026-04-19
- Branch: phase24-room-go-protobuf
- Status: completed

## Frozen legacy Room server paths
- network/runtime/room_service_bootstrap.gd
- network/session/runtime/server_room_service.gd
- network/session/runtime/server_room_registry.gd
- network/session/runtime/room_authority_runtime.gd
- network/transport/enet_battle_transport.gd (Room scene scope)

## Rule
- No new formal Room features are allowed on the legacy Godot Room server stack listed above.
- New Phase24 Room features must go to the new Go + protobuf + C# path.

## Step 2
- Date: 2026-04-19
- Status: completed
- Added proto source of truth under `proto/qqt/room/v1` and `proto/qqt/internal/game/v1`.
- Added `buf.yaml` and `buf.gen.yaml` with Go and C# generation targets.

## Step 3
- Date: 2026-04-19
- Status: completed
- Added room manifest exporter: `tools/content_pipeline/generators/generate_room_manifest.gd`.
- Wired exporter into `tools/content_pipeline/content_pipeline_runner.gd`.
- Added output target placeholder: `build/generated/room_manifest/room_manifest.json`.
- Added content contract tests:
  - `tests/contracts/content/room_manifest_export_contract_test.gd`
  - `tests/contracts/content/room_manifest_matches_catalog_contract_test.gd`

## Step 4
- Date: 2026-04-19
- Status: completed
- Added `services/room_service` Go service skeleton with:
  - `cmd/room_service/main.go`
  - `internal/{auth,config,domain,manifest,registry,roomapp,wsapi,gameclient,observability}`
  - `scripts/run-room-service.ps1`
  - `.env.example`
  - `go.mod`
- Implemented startup flow: env config load, manifest load, registry init, ws server start, `/healthz` and `/readyz`, SIGTERM graceful shutdown.
- Verification: `go test ./...` passed under `services/room_service`.

## Step 5
- Date: 2026-04-19
- Status: completed
- Implemented minimal in-memory room authority flow in `services/room_service/internal/roomapp/service.go`:
  - `CreateRoom`
  - `JoinRoom`
  - `ResumeRoom`
  - `LeaveRoom`
  - `UpdateProfile`
  - `UpdateSelection`
  - `ToggleReady`
  - `SnapshotProjection`
- Added manifest-based loadout/selection legality checks.
- Added tests:
  - `services/room_service/internal/roomapp/create_room_test.go`
  - `services/room_service/internal/roomapp/join_room_test.go`
  - `services/room_service/internal/roomapp/resume_room_test.go`
  - `services/room_service/internal/roomapp/toggle_ready_test.go`
- Verification: `go test ./...` passed under `services/room_service`.

## Step 6
- Date: 2026-04-19
- Status: completed
- Implemented Room WebSocket + protobuf gateway under `services/room_service/internal/wsapi/`:
  - `server.go`
  - `connection.go`
  - `decoder.go`
  - `encoder.go`
  - `dispatcher.go`
- Behavior added:
  - `GET /ws` websocket upgrade
  - Binary frame required, non-binary rejected
  - Protobuf-wire envelope decode for create/join/resume
  - Per-connection `connection_id`
  - Operation path requires `request_id`
  - Snapshot push includes `snapshot_revision`
  - Invalid payload returns `OperationRejected`
- Added tests:
  - `services/room_service/internal/wsapi/ws_create_room_test.go`
  - `services/room_service/internal/wsapi/ws_join_room_test.go`
  - `services/room_service/internal/wsapi/ws_resume_room_test.go`
- Dependencies added in `services/room_service/go.mod`:
  - `github.com/gorilla/websocket`
  - `google.golang.org/protobuf`
- Verification: `go test ./...` passed under `services/room_service`.

## Step 7
- Date: 2026-04-19
- Status: completed
- Added internal protobuf control plane over gRPC in `services/game_service/internal/rpcapi/`:
  - `room_control_service.go`
  - `grpc_server.go`
- Implemented RPC methods:
  - `EnterPartyQueue`
  - `CancelPartyQueue`
  - `GetPartyQueueStatus`
  - `CreateManualRoomBattle`
  - `CommitAssignmentReady`
- Kept existing internal HTTP JSON APIs unchanged for compatibility.
- Integrated gRPC server startup into `services/game_service/cmd/game_service/main.go`.
- Added config `GAME_GRPC_ADDR` in `services/game_service/internal/config/config.go`.
- Added RPC tests:
  - `services/game_service/internal/rpcapi/party_queue_rpc_test.go`
  - `services/game_service/internal/rpcapi/manual_room_battle_rpc_test.go`
  - `services/game_service/internal/rpcapi/assignment_commit_rpc_test.go`
- Verification: `go test ./internal/rpcapi ./cmd/game_service` passed.

## Step 8
- Date: 2026-04-19
- Status: completed
- Human prerequisite confirmed: Godot .NET solution/csproj created (`QQTang.sln`, `QQTang.csproj`).
- Added C# Room protocol layer directories and files:
  - `network/client_net/generated/proto/qqt/room/v1/`
  - `network/client_net/room/RoomProtoCodec.cs`
  - `network/client_net/room/RoomWsClient.cs`
  - `network/client_net/room/RoomSnapshotMapper.cs`
  - `network/client_net/room/RoomClientSessionState.cs`
  - `network/client_net/shared/ProtoEnvelopeUtil.cs`
  - `network/client_net/shared/WsBinaryFrameReader.cs`
- Verification: `dotnet build QQTang.csproj` passed.

## Step 9
- Date: 2026-04-19
- Status: completed
- Refactored `network/runtime/client_room_runtime.gd` into a GDScript facade that prefers C# Room ws client.
- Removed direct ENet bootstrap dependency from normal path; kept legacy `_transport` fallback only for compatibility tests.
- Added C# Room ws client message bridge:
  - `RoomWsClient.SendMessage(Dictionary)`
  - `RoomWsClient.MessageReceived(Dictionary)`
- Kept existing public methods/signals in `ClientRoomRuntime` stable.
- Added integration tests:
  - `tests/integration/network/client_room_runtime_ws_proto_create_room_test.gd`
  - `tests/integration/network/client_room_runtime_ws_proto_join_room_test.gd`
  - `tests/integration/network/client_room_runtime_ws_proto_resume_room_test.gd`
- Verification: `dotnet build QQTang.csproj` passed.

## Step 10
- Date: 2026-04-19
- Status: completed
- Added manifest legality query layer:
  - `services/room_service/internal/manifest/query.go`
  - `ValidateCustomRoomSelection`
  - `ValidateMatchRoomConfig`
  - `ResolveMapPool`
  - `ValidateTeamAndPlayerCount`
- Integrated room selection legality path to query layer in:
  - `services/room_service/internal/roomapp/service.go`
- Fixed `UpdateSelection` ordering bug and enforced validation by current room member count.
- Synced room runtime capacity on selection change with resolved map (`room.MaxPlayerCount`).
- Verification: `go test ./...` passed under `services/room_service`.

## Step 11
- Date: 2026-04-19
- Status: completed
- Added formal governance directories:
  - `network/runtime/{boot,room_client,diagnostics,errors,legacy}/`
  - `network/session/room/{client,model,shared}/`
  - `network/session/battle/{client,shared}/`
  - `network/session/legacy/`
  - `network/transport/{battle,legacy}/`
- Migrated new Room client runtime code to formal path:
  - `network/runtime/room_client/client_room_runtime.gd`
  - `network/runtime/room_client/room_client_gateway.gd`
- Migrated Room session model code to formal path:
  - `network/session/room/model/room_directory_entry.gd`
  - `network/session/room/model/room_directory_snapshot.gd`
- Kept legacy paths as thin forwarding shells with deprecation comments:
  - `network/runtime/client_room_runtime.gd`
  - `network/runtime/room_client_gateway.gd`
  - `network/session/runtime/room_directory_entry.gd`
  - `network/session/runtime/room_directory_snapshot.gd`

## Step 12
- Date: 2026-04-19
- Status: completed
- Moved old Godot Room server formal implementations into legacy directories:
  - `network/runtime/legacy/room_service_bootstrap.gd`
  - `network/session/legacy/server_room_service.gd`
  - `network/session/legacy/server_room_registry.gd`
  - `network/session/legacy/server_room_member_service.gd`
  - `network/session/legacy/server_room_message_dispatcher.gd`
  - `network/session/legacy/server_room_resume_service.gd`
  - `network/session/legacy/server_room_battle_handoff_service.gd`
  - `network/session/legacy/room_authority_runtime.gd`
- Replaced old formal paths with deprecated forwarding shells only:
  - `network/runtime/room_service_bootstrap.gd`
  - `network/session/runtime/server_room_service.gd`
  - `network/session/runtime/server_room_registry.gd`
  - `network/session/runtime/server_room_member_service.gd`
  - `network/session/runtime/server_room_message_dispatcher.gd`
  - `network/session/runtime/server_room_resume_service.gd`
  - `network/session/runtime/server_room_battle_handoff_service.gd`
  - `network/session/runtime/room_authority_runtime.gd`
- Manual step completed:
  - `scenes/network/room_service_scene.tscn` removed in Godot editor.
- Follow-up fix:
  - Updated startup scripts to use `res://scenes/network/dedicated_server_scene.tscn`:
    - `scripts/run-room-service.ps1`
    - `network/scripts/run-room-service.ps1`

## Step 13
- Date: 2026-04-19
- Status: completed
- Added service Dockerfiles:
  - `services/room_service/Dockerfile`
  - `services/game_service/Dockerfile`
  - `services/account_service/Dockerfile`
  - `services/ds_manager_service/Dockerfile`
- Added Phase24 compose files:
  - `deploy/docker/docker-compose.phase24.dev.yml`
  - `deploy/docker/docker-compose.phase24.test.yml`
- Room image now includes manifest artifact:
  - `build/generated/room_manifest/room_manifest.json` copied into image.
- Health check command unified across service images:
  - `wget -qO- http://127.0.0.1:${SERVICE_HEALTH_PORT}/healthz`

## Step 14
- Date: 2026-04-19
- Status: completed
- Added proto/manifest tests:
  - `services/room_service/internal/manifest/loader_test.go`
  - `services/room_service/internal/wsapi/proto_roundtrip_test.go`
- Added Room base-flow tests:
  - `services/room_service/internal/roomapp/leave_room_test.go`
  - `services/room_service/internal/roomapp/update_selection_test.go`
- Added Room error-path tests:
  - `services/room_service/internal/roomapp/error_paths_test.go`
  - covers invalid room ticket, stale room id, forbidden loadout, illegal match mode set.
- Added client bridge/runtime contract test:
  - `tests/contracts/runtime/room_client_facade_contract_test.gd`
- Updated moved-path port contract targets:
  - `tests/contracts/runtime/room_default_port_contract_test.gd`
  - now checks `network/runtime/legacy/room_service_bootstrap.gd` and `network/runtime/room_client/client_room_runtime.gd`.
- Verification:
  - `go test ./...` passed under `services/room_service`.

## Step 15
- Date: 2026-04-19
- Status: completed
- Updated source-of-truth and architecture docs:
  - `docs/current_source_of_truth.md`
  - `docs/architecture/runtime_topology.md`
  - `docs/architecture/network_control_plane.md`
  - `docs/platform_room/room_service_runtime_contract.md`
- Added new architecture topic docs:
  - `docs/architecture/room_protocol.md`
  - `docs/architecture/room_manifest.md`
- Documentation now reflects:
  - formal Room Service entrypoint is Go (`services/room_service/cmd/room_service/main.go`);
  - client Room protocol is WebSocket + protobuf with C# protocol layer;
  - old Godot Room server paths are legacy/deprecated;
  - Room legality source is `room_manifest.json`.

## Post-Phase Cleanup
- Date: 2026-04-19
- Status: completed
- Removed deprecated forwarding shells and switched all references to formal new paths.
- Deleted old shell paths:
  - `network/runtime/client_room_runtime.gd`
  - `network/runtime/room_client_gateway.gd`
  - `network/runtime/room_service_bootstrap.gd`
  - `network/session/runtime/room_authority_runtime.gd`
  - `network/session/runtime/room_directory_entry.gd`
  - `network/session/runtime/room_directory_snapshot.gd`
  - `network/session/runtime/server_room_battle_handoff_service.gd`
  - `network/session/runtime/server_room_member_service.gd`
  - `network/session/runtime/server_room_message_dispatcher.gd`
  - `network/session/runtime/server_room_registry.gd`
  - `network/session/runtime/server_room_resume_service.gd`
  - `network/session/runtime/server_room_service.gd`
- Updated runtime/test/scene text references to:
  - `network/runtime/room_client/*`
  - `network/runtime/legacy/*`
  - `network/session/legacy/*`
  - `network/session/room/model/*`
