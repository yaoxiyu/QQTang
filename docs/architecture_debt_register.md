# Architecture Debt Register

## DEBT-012 battle input batch redundancy is fixed-window instead of ack-trimmed
- Risk level: P1
- Status: open
- Related dirs: `network/session/runtime/`, `network/transport/`, `gameplay/simulation/input/`, `gameplay/native_bridge/`, `addons/qqt_native/src/sync/`, `docs/architecture/battle_sync.md`
- Forbidden new-logic dirs: ad-hoc client-only input packet size hacks; lowering redundancy without using authoritative acknowledgement; duplicate-input filtering outside the input buffer or authority ingestion boundary
- Current compromise: Clients send `INPUT_BATCH` with a fixed recent-frame window. Authority sends `INPUT_ACK` and clients record the latest confirmed tick, while authority batch coalescing drops stale authority snapshots. This confirms progress, but input resend size is not trimmed from an ack-driven send window and duplicate input frames are not modeled as a first-class protocol concern.
- Planned phase: battle-input-ack-window-cleanup
- Done definition: define an ack-driven input resend window; client only resends frames newer than the latest authoritative ack with a bounded safety margin; authority input ingestion treats duplicate `(peer_id, tick_id, seq)` frames idempotently; packet metrics expose batch frame count and encoded byte size; MTU promotion warnings no longer occur under normal battle input rates; regression tests cover duplicate input batch delivery, out-of-order ack, stale ack, and packet-size budget.
- Owner: battle-sync
- Linked tests/docs: `network/session/runtime/client_runtime.gd`, `network/session/runtime/authority_runtime.gd`, `network/session/runtime/server_session.gd`, `gameplay/simulation/input/input_buffer.gd`, `docs/architecture/battle_sync.md`

## DEBT-011 manual battle status sync uses queue-shaped polling contract
- Risk level: P2
- Status: open
- Related dirs: `services/room_service/internal/roomapp/`, `services/room_service/internal/gameclient/`, `services/game_service/internal/assignment/`, `services/game_service/internal/rpcapi/`, `proto/qqt/internal/game/v1/`
- Forbidden new-logic dirs: new manual battle lifecycle logic that treats matchmaking queue state as the semantic source of truth; frontend-only room phase recovery after battle finalize; direct room FSM writes outside `RoomTransitionEngine`
- Current compromise: Custom-room battles write `room.QueueState.QueueEntryID = assignment_id` and reuse `GetPartyQueueStatus` / queue-shaped projection to poll manual assignment finalization. This is functionally correct because `game_service.assignment` is the authoritative finalized source and room_service still converges through `ApplyQueueProjection`, `clearBattleStateProjection`, `releaseMembersToIdle`, and `finalizeRoomTransition`. The naming is not clean: a manual battle assignment is not a matchmaking queue entry.
- Planned phase: room-battle-state-cleanup
- Done definition: introduce a neutral typed control-plane operation such as `GetBattleAssignmentStatus` or `SyncBattleStatus`; room_service tracks manual battle return through battle/assignment status fields instead of queue naming; `QueueState` remains reserved for real matchmaking queues; finalized manual battle returns room to `idle` through `RoomTransitionEngine`; host leave and post-battle ready/start regressions remain covered by committed roomapp/wsapi tests; docs `docs/architecture/room_state_machine.md` and `docs/architecture/network_control_plane.md` describe the split explicitly.
- Owner: room-state-machine
- Linked tests/docs: `services/room_service/internal/roomapp/start_manual_room_battle_test.go`, `services/room_service/internal/roomapp/battle_handoff_projection_test.go`, `services/game_service/internal/assignment/assignment_service.go`, `services/game_service/internal/rpcapi/room_control_service.go`, `docs/architecture/room_state_machine.md`, `docs/architecture/network_control_plane.md`

## DEBT-010 battle authority batch consumption not coalesced
- Risk level: P1
- Status: closed
- Related dirs: `network/session/runtime/`, `network/session/`, `gameplay/network/rollback/`
- Forbidden new-logic dirs: per-message authority rollback paths that bypass a batch coalescing boundary
- Planned phase: phase32-native-frame-sync-refactor
- Done definition: client transport poll batches are coalesced before runtime ingestion; stale authority snapshots are dropped; one rendered client frame runs at most one rollback/resync from the latest useful authority snapshot; authority events remain ordered and are not lost when intermediate snapshots are skipped; profiling counters cover incoming batch size, checkpoint count, rollback count, replay ticks, and late input handling; native shadow parity is covered before execute mode is enabled.
- Owner: battle-sync
- Last updated: 2026-04-24
- Linked tests/docs: `docs/architecture/battle_sync.md`, `docs/battle_sync_rule_audit.md`, `tests/unit/network/authority_batch_coalescer_test.gd`, `tests/unit/network/client_runtime_authority_batch_test.gd`, `tests/integration/network/client_authority_batch_coalescing_test.gd`, `tests/integration/network/client_authority_burst_recovery_test.gd`, `tests/integration/network/client_authority_fault_profile_test.gd`, `tests/performance/native/native_frame_sync_soak_test.gd`

## DEBT-001 app_runtime_root orchestration overload
- Risk level: P1
- Status: closed
- Related dirs: `app/flow/`
- Forbidden new-logic dirs: `app/flow/app_runtime_root.gd`
- Planned phase: milestone-2026-q2-runtime
- Done definition: root stays as orchestrator only, delegated modules own init/context/network/registry, root size <= 450 lines
- Owner: front-runtime
- Last updated: 2026-04-19
- Linked tests/docs: `tests/contracts/runtime/runtime_initialization_contract_test.gd`, `tests/contracts/runtime/runtime_context_objects_contract_test.gd`, `tests/contracts/runtime/app_runtime_root_boundary_contract_test.gd`

## DEBT-002 room scene controller mixed concerns
- Risk level: P1
- Status: closed
- Related dirs: `scenes/front/`, `app/front/room/`
- Forbidden new-logic dirs: `scenes/front/room_scene_controller.gd`
- Planned phase: milestone-2026-q2-front-room
- Done definition: selector, submit, snapshot logic moved to dedicated collaborators, controller <= 420 lines
- Owner: front-runtime
- Last updated: 2026-04-19
- Linked tests/docs: `tests/integration/front/room_to_loading_to_battle_flow_test.gd`, `tests/contracts/runtime/room_scene_controller_boundary_contract_test.gd`, `docs/architecture/front_flow.md`

## DEBT-003 HTTP lifecycle not fully unified
- Risk level: P1
- Status: closed
- Related dirs: `app/infra/http/`, `app/front/`, `network/services/`, `network/session/runtime/`
- Forbidden new-logic dirs: direct `HTTPClient` lifecycle in gateways and service clients
- Planned phase: milestone-2026-q2-http
- Done definition: all high-frequency clients call shared executor, log fields contain method/url/status/error/log_tag
- Owner: network-runtime
- Last updated: 2026-04-19
- Linked tests/docs: `tests/unit/front/http/http_url_parser_test.gd`, `tests/unit/infra/http/http_request_executor_test.gd`, `tests/contracts/path/no_direct_httpclient_in_runtime_contract_test.gd`

## DEBT-003A internal auth protocol fork
- Risk level: P1
- Status: closed
- Related dirs: `network/session/runtime/`, `app/infra/http/`, `network/services/`
- Forbidden new-logic dirs: legacy `X-Internal-Secret` header paths
- Planned phase: milestone-2026-q2-http
- Done definition: internal client only emits formal HMAC headers, legacy env fallback exists only at single compat read point
- Owner: network-runtime
- Last updated: 2026-04-19
- Linked tests/docs: `tests/unit/network/internal_auth_signer_test.gd`, `tests/unit/network/server_match_finalize_reporter_test.gd`, `tests/contracts/runtime/internal_finalize_auth_contract_test.gd`

## DEBT-004 legacy compatibility path naming ambiguity
- Risk level: P2
- Status: closed
- Related dirs: `network/session/runtime/`
- Forbidden new-logic dirs: `network/session/runtime/server_room_runtime_compat_impl.gd`
- Planned phase: milestone-2026-q2-runtime-bridge
- Done definition: legacy/compat paths removed, and contract tests block any reintroduction.
- Owner: network-runtime
- Last updated: 2026-04-21
- Linked tests/docs: `tests/contracts/path/no_legacy_compat_assets_contract_test.gd`, `tests/contracts/path/no_legacy_runtime_bridge_contract_test.gd`, `tests/contracts/path/no_removed_room_runtime_test_reference_contract_test.gd`, `tests/contracts/path/canonical_path_contract_test.gd`

## DEBT-005 cross-service contract coverage gap
- Risk level: P1
- Status: closed
- Related dirs: `tests/contracts/`, `tests/integration/e2e/`, `services/game_service/`, `services/ds_manager_service/`
- Forbidden new-logic dirs: ad-hoc local debug scripts as sole verification source
- Planned phase: milestone-2026-q2-contracts
- Done definition: battle lifecycle critical links are covered by committed suites (DSM internal auth/lifecycle, game internal handlers, room_service registry/wsapi, Battle DS E2E) and aggregated by cross-service contract suite.
- Owner: architecture
- Last updated: 2026-04-20
- Linked tests/docs: `services/ds_manager_service/internal/httpapi/dsm_internal_auth_contract_test.go`, `services/ds_manager_service/internal/httpapi/ds_control_plane_lifecycle_test.go`, `services/game_service/internal/httpapi/internal_battle_manifest_handler_test.go`, `services/game_service/internal/httpapi/internal_assignment_handler_test.go`, `services/game_service/internal/httpapi/internal_finalize_handler_test.go`, `services/room_service/internal/registry/registry_test.go`, `services/room_service/internal/wsapi/ws_directory_visibility_test.go`, `tests/integration/e2e/battle_entry_invalid_ticket_e2e_test.gd`, `tests/integration/e2e/battle_resume_window_e2e_test.gd`, `tests/integration/e2e/battle_finalize_payload_e2e_test.gd`, `tests/scripts/run_cross_service_contract_suite.ps1`

## DEBT-006 release hygiene and evidence governance
- Risk level: P1
- Status: closed
- Related dirs: `.gitignore`, `tests/reports/`, `tools/release/`, `services/`
- Forbidden new-logic dirs: checked-in local `.env`, root-level mixed latest/archive reports
- Planned phase: milestone-2026-q2-release
- Done definition: release sanity, local validation, and CI workflow are formalized as official entrypoints; release sanity blocks legacy/compat regressions and dirty release artifacts.
- Owner: build-and-release
- Last updated: 2026-04-21
- Linked tests/docs: `tools/release/release_sanity_check.py`, `scripts/validation/run_validation.ps1`, `.github/workflows/validate.yml`, `tests/contracts/path/no_legacy_node_test_style_contract_test.gd`, `tests/contracts/path/no_legacy_test_runner_reference_contract_test.gd`, `tests/contracts/path/no_legacy_compat_assets_contract_test.gd`, `tests/contracts/path/no_legacy_runtime_bridge_contract_test.gd`, `tests/contracts/path/no_removed_room_runtime_test_reference_contract_test.gd`

## DEBT-007 room protocol fake protobuf path
- Risk level: P1
- Status: closed
- Related dirs: `network/client_net/`, `network/runtime/room_client/`, `services/room_service/internal/wsapi/`, `proto/qqt/room/v1/`
- Forbidden new-logic dirs: `network/runtime/legacy/`, `network/session/legacy/`, `network/session/runtime/server_room_*`, `network/runtime/room_service_bootstrap.gd`
- Planned phase: phase25-room-protocol-closure
- Done definition: room client send and receive path use generated protobuf envelope end-to-end, room_service wsapi no longer uses hand-written protowire as formal path, snapshot projection excludes reconnect token fields
- Owner: room-protocol
- Last updated: 2026-04-19
- Linked tests/docs: `services/room_service/internal/wsapi/proto_roundtrip_test.go`, `services/room_service/internal/wsapi/ws_dispatcher_full_coverage_test.go`, `tests/contracts/runtime/room_client_runtime_no_json_path_contract_test.gd`, `tests/contracts/runtime/room_client_runtime_no_formal_transport_fallback_contract_test.gd`, `docs/architecture/room_protocol.md`

## DEBT-008 room control plane weak typed grpc
- Risk level: P1
- Status: closed
- Related dirs: `services/room_service/internal/gameclient/`, `services/game_service/internal/rpcapi/`, `proto/qqt/internal/game/v1/`
- Forbidden new-logic dirs: `services/game_service/internal/rpcapi/grpc_server.go` manual `grpc.ServiceDesc` and `structpb.Struct` formal request path
- Planned phase: phase25-room-protocol-closure
- Done definition: room_service gameclient uses generated typed grpc client, game_service rpcapi uses generated service registration and typed request and response only, room control operations pass through typed mapper
- Owner: control-plane
- Last updated: 2026-04-19
- Linked tests/docs: `services/game_service/internal/rpcapi/party_queue_rpc_test.go`, `services/game_service/internal/rpcapi/manual_room_battle_rpc_test.go`, `services/game_service/internal/rpcapi/assignment_commit_rpc_test.go`, `services/game_service/internal/rpcapi/grpc_server.go`, `docs/architecture/network_control_plane.md`

## DEBT-009 client room sdk test coverage missing
- Risk level: P1
- Status: closed
- Related dirs: `tests/csharp/QQTang.RoomClient.Tests/`, `network/client_net/room/`, `network/client_net/generated/`
- Forbidden new-logic dirs: protocol changes in `network/client_net/room/` without committed csharp tests
- Planned phase: phase25-room-protocol-closure
- Done definition: dedicated csharp test project exists in solution, envelope factory and codec and parser and snapshot mapper and canonical mapper are covered, tests run in local validation and CI entry
- Owner: client-sdk
- Last updated: 2026-04-19
- Linked tests/docs: `tests/csharp/QQTang.RoomClient.Tests/RoomClientEnvelopeFactoryTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomProtoCodecTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomServerEnvelopeParserTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomSnapshotMapperTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomCanonicalMessageMapperTests.cs`, `scripts/validation/run_validation.ps1`, `.github/workflows/validate.yml`
