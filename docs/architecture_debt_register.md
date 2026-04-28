# Architecture Debt Register

## DEBT-016 Godot runtime shutdown leaves leaked objects/resources
- Risk level: P2
- Status: open
- Related dirs: `app/flow/`, `network/session/`, `network/runtime/`, `scenes/battle/`, `tests/unit/front/`, `tests/integration/`
- Forbidden new-logic dirs: shutdown handling hidden in ad-hoc scene `_exit_tree` code without a shared lifecycle owner
- Planned phase: milestone-2026-q2-runtime-shutdown-hygiene
- Current evidence:
  - Current partial fix added `RuntimeShutdownCoordinator`, `RuntimeShutdownContext`, `RuntimeShutdownHandle`, and `RuntimeShutdownLogClassifier`
  - `ClientRuntimeShutdownHandle` now owns client runtime shutdown cleanup; `client_runtime.gd`, `authority_runtime.gd`, `server_session.gd`, `app_runtime_root.gd`, `enet_battle_transport.gd`, `battle_main_controller.gd`, and `battle_dedicated_server_bootstrap.gd` now expose shutdown-handle style APIs
  - `battle_dedicated_server_bootstrap.gd` no longer has an `_exit_tree()` path that only shuts down `_transport`; it routes through the coordinator and disconnects runtime/transport signals first
  - Latest manual run `logs/clients_dev_20260427_160402/client*.godot.log` reports `ObjectDB instances leaked at exit` and `3 resources still in use at exit` after process shutdown
  - Latest interrupted DS `logs/battle_ds/battle_33a33a968ec1b7d1.log` reports `Thread object is being destroyed without its completion having been realized`, RID leaks, and `BUG: Unreferenced static string` at exit
  - Existing test reports under `tests/reports/latest/*` already show recurring Godot orphan/RID/resource leaks even when tests pass
- Initial solution:
  - Add a shared shutdown coordinator that orders transport disconnect, runtime module unregister, thread join, timer stop, and scene-owned resource release
  - Add test helpers that explicitly `queue_free` fake runtime/controller nodes used by front room unit tests
  - Make dev launcher stop DS through a graceful control-plane shutdown before killing processes; keep forced kill as fallback only
  - Add a log classifier so expected forced-shutdown exit noise is separated from real runtime leak regressions
- Done definition:
  - Normal client exit after lobby -> battle -> return -> lobby has no `ObjectDB instances leaked`, `resources still in use`, or CanvasItem/RID leak warnings
  - Normal DS finalize and shutdown joins all threads and has no RID/resource leak warnings
  - Forced-stop logs are classified as expected interruption and do not mask non-shutdown errors
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1` passes before runtime tests
  - Front room/runtime targeted suites pass with zero Godot orphan/resource leak warnings
- Owner: runtime-lifecycle
- Last updated: 2026-04-27
- Linked tests/docs: `app/flow/app_runtime_root.gd`, `network/session/room_session_controller.gd`, `network/runtime/battle_dedicated_server_bootstrap.gd`, `scenes/battle/battle_main_controller.gd`, `tests/reports/latest/current_review_latest.txt`

## DEBT-015 room frontend receives placeholder authoritative snapshots during battle
- Risk level: P2
- Status: closed
- Related dirs: `app/front/room/`, `network/runtime/room_client/`, `network/session/`, `scenes/front/`
- Forbidden new-logic dirs: UI code that treats `member_count=0 phase="" revision=0` as a real room snapshot
- Planned phase: milestone-2026-q2-room-snapshot-boundary
- Current evidence:
  - Closed by Current room snapshot validity boundary
  - `RoomSnapshotValidity` classifies null/empty/dedicated missing-room placeholders before projection
  - `RoomSnapshotCache` preserves last-good room snapshots and rejects placeholder/stale snapshots
  - `room_use_case.gd` and `room_snapshot_flow.gd` both guard authoritative snapshot application
  - `RoomTransportConnectionReason` separates create/join/recover warnings from reuse/battle_return/directory reconnect noise
- Initial solution:
  - Introduce an explicit snapshot validity contract: room snapshots with empty phase and revision 0 are placeholders and must not be applied as authoritative state
  - During battle-active flow, pause room snapshot application or route it through a battle-safe cache that cannot overwrite current room members/capabilities
  - Split room transport connection events from room-entry pending state; log `transport_connected_without_pending_entry` only when it is actionable, not for benign reconnect/reuse paths
  - Add regression tests for battle-active room snapshot suppression and room return recovery preserving members/capabilities
- Done definition:
  - Battle-active logs no longer emit repeated empty authoritative room snapshots
  - Empty placeholder snapshots cannot overwrite non-empty room state in view model/runtime state
  - Benign room directory/room transport reconnects no longer produce anomaly warnings
  - Room return recovery still emits `can_toggle_ready=true` with correct member state
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1` passes before runtime tests
- Owner: front-runtime
- Last updated: 2026-04-27
- Linked tests/docs: `app/front/room/room_use_case.gd`, `app/front/room/room_use_case_runtime_state.gd`, `app/front/room/room_view_model_builder.gd`, `app/front/room/recovery/room_enter_flow.gd`, `network/runtime/room_client/client_room_runtime.gd`, `scenes/front/room_scene_snapshot_coordinator.gd`

## DEBT-014 battle payload budget still exceeds unreliable MTU under normal play
- Risk level: P1
- Status: open
- Related dirs: `network/session/runtime/`, `network/transport/`, `gameplay/simulation/`, `gameplay/native_bridge/`, `addons/qqt_native/src/sync/`
- Forbidden new-logic dirs: ad-hoc reliability promotion decisions outside the battle transport/batch codec boundary
- Planned phase: milestone-2026-q2-battle-payload-budget
- Current evidence:
  - Current partial fix added `BattleWireBudgetContract`, `BattleWireBudgetProfiler`, `InputBatchV2`, `StateSummaryV2` core/delta/checkpoint builders, and native QQTS v2 high-frequency codec entrypoints
  - Legacy `INPUT_FRAME` network protocol references were removed from authority runtime, DS routing, battle transport channels, and message type constants
  - `TransportMessageCodec.decode_message(Dictionary)` now rejects high-frequency message dictionaries, so INPUT_BATCH/STATE_SUMMARY/STATE_DELTA must pass through QQTS payload decode
  - Transport metrics now expose type-level promotion counts, last promoted payload bytes, max payload bytes, and p95 payload bytes
  - Debt remains open until 2P steady-state and 4P soak MTU evidence is captured
  - Latest run `logs/clients_dev_20260427_160402/client*.godot.log` contains 2549 `QQT_INPUT_BATCH_BUDGET_WARN` entries
  - Latest run contains 31 client-side and 16 DS-side `battle unreliable payload promoted to reliable` entries
  - DS `STATE_SUMMARY` payloads reached roughly 1696-2856 bytes; client `INPUT_BATCH` payloads reached roughly 1200-1352 bytes, causing reliable-channel promotion
- Initial solution:
  - Measure encoded section sizes separately for input batch envelope, per-frame payload, state summary header, player updates, grid/bubble/jelly sections, and debug metadata
  - Reduce `INPUT_BATCH` by sending sparse changed frames only, compacting tick deltas, and lowering safety-margin resend once ack health is stable
  - Reduce `STATE_SUMMARY` by delta-compressing unchanged sections and splitting large non-critical summary sections away from per-tick unreliable updates
  - Add MTU budget tests that fail when common 2-player and 4-player payloads exceed the target unreliable budget
  - Keep reliability promotion metric, but make it an exceptional fallback instead of an expected steady-state path
- Done definition:
  - Normal 2-player battle produces zero steady-state `QQT_INPUT_BATCH_BUDGET_WARN`
  - Normal 2-player battle produces zero steady-state unreliable-to-reliable promotions after initial bootstrap
  - 4-player soak keeps p95 `INPUT_BATCH` and `STATE_SUMMARY` encoded size under the configured unreliable MTU budget
  - Metrics expose per-section byte contribution for input and state summary packets
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1` passes before runtime tests
- Owner: battle-sync
- Last updated: 2026-04-27
- Linked tests/docs: `network/session/runtime/client_runtime.gd`, `network/session/runtime/authority_runtime.gd`, `network/transport/enet_battle_transport.gd`, `gameplay/simulation/input/player_input_frame.gd`, `tests/performance/native/native_frame_sync_soak_test.gd`, `docs/architecture/battle_sync.md`

## DEBT-013 runtime/front boundary line-limit contracts regressed
- Risk level: P1
- Status: closed
- Related dirs: `app/flow/`, `network/session/runtime/`, `scenes/front/`
- Forbidden new-logic dirs: `app/flow/app_runtime_root.gd`, `network/session/runtime/client_runtime.gd`, `scenes/front/room_scene_controller.gd`
- Planned phase: milestone-2026-q2-runtime-boundary-reclosure
- Current evidence:
  - Closed by Current boundary reclosure
  - `app/flow/app_runtime_root.gd` is 437 lines, under the 450-line contract
  - `network/session/runtime/client_runtime.gd` is under the 650-line contract after extracting input batch, authority ingestion, prediction policy, and shutdown handle collaborators
  - `scenes/front/room_scene_controller.gd` is a thin scene script entrypoint under the 420-line contract, and formal room layout/loadout/slot/popup/theme logic lives under `scenes/front/room/room_formal_*.gd`
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/run_refactor_validation.ps1` passed with 113/113 tests
- Done definition:
  - `app/flow/app_runtime_root.gd` is reduced to <= 450 lines without moving orchestration responsibilities back into root
  - `network/session/runtime/client_runtime.gd` is reduced to <= 650 lines by moving cohesive input-batch/metrics/runtime helper logic into collaborators
  - `scenes/front/room_scene_controller.gd` is reduced to <= 420 lines by moving view wiring and UI event glue into dedicated collaborators or scene-owned nodes
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1` passes before runtime tests
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/run_refactor_validation.ps1` passes with 0 failures
- Owner: front-runtime
- Last updated: 2026-04-27
- Linked tests/docs: `tests/contracts/runtime/app_runtime_root_boundary_contract_test.gd`, `tests/contracts/runtime/battle_runtime_boundary_contract_test.gd`, `tests/contracts/runtime/room_scene_controller_boundary_contract_test.gd`, `app/flow/app_runtime_root.gd`, `network/session/runtime/client_runtime.gd`, `scenes/front/room_scene_controller.gd`

## DEBT-012 battle input batch redundancy is fixed-window instead of ack-trimmed
- Risk level: P1
- Status: closed
- Related dirs: `network/session/runtime/`, `network/transport/`, `gameplay/simulation/input/`, `gameplay/native_bridge/`, `addons/qqt_native/src/sync/`, `docs/architecture/battle_sync.md`
- Closed by: phase_debt_ack_battle_assignment_cleanup (Current)
- Closing conditions:
  - INPUT_BATCH_RECENT_FRAME_COUNT removed, replaced by ack-trimmed window (INPUT_ACK_SAFETY_MARGIN_TICKS + INPUT_BATCH_MAX_FRAMES hard cap)
  - Client ack cursor (last_confirmed_tick) is monotonic, stale ack counted
  - INPUT_BATCH envelope carries first_tick/latest_tick/ack_base_tick/frame_count
  - Wire frames use action_bits encoding (bit0=place, bit1=skill1, bit2=skill2)
  - Native input buffer: identity dedup (peer_id/tick_id/seq), payload hash conflict detection, higher-seq replacement, stale seq drop, too-late drop (no retarget), ack monotonic
  - Packet budget metrics (INPUT_BATCH_BUDGET_WARN), frame_count/encoded_bytes against thresholds
  - Authority INPUT_BATCH envelope validation (protocol_version, peer_id, frame_count, first_tick/latest_tick, per-frame peer_id)
  - Tests: duplicate_ignored, duplicate_conflict, higher_seq replacement, stale_seq drop, too_late no retarget, ack monotonic, fallback action cleared
  - merge_input_frame removed, late_retarget removed (metrics frozen at 0)
- Owner: battle-sync
- Last updated: 2026-04-27
- Linked tests/docs: `network/session/runtime/client_runtime.gd`, `network/session/runtime/authority_runtime.gd`, `gameplay/simulation/input/player_input_frame.gd`, `addons/qqt_native/src/sync/native_input_buffer.h`, `addons/qqt_native/src/sync/native_input_buffer.cpp`, `tests/unit/native/native_input_buffer_test.gd`

## DEBT-011 manual battle status sync uses queue-shaped polling contract
- Risk level: P2
- Status: closed
- Related dirs: `services/room_service/internal/roomapp/`, `services/room_service/internal/gameclient/`, `services/game_service/internal/assignment/`, `services/game_service/internal/rpcapi/`, `proto/qqt/internal/game/v1/`
- Closed by: phase_debt_ack_battle_assignment_cleanup (Current)
- Closing conditions:
  - StartManualRoomBattle no longer writes QueueState (QueueEntryID/Phase/StatusText)
  - collectQueueSyncTargets only collects match rooms (casual_match_room/ranked_match_room), skips manual rooms
  - New RPC GetBattleAssignmentStatus added to proto and generated (Go + C#)
  - game_service RoomControlService implements GetBattleAssignmentStatus via assignment.GetStatus
  - room_service gameclient adds GetBattleAssignmentStatus with typed input/result models
  - collectBattleSyncTargets and SyncBattleAssignmentStatus added, calling GetBattleAssignmentStatus instead of GetPartyQueueStatus
  - applyBattleAssignmentProjection only modifies BattleState/RoomPhase, never QueueState
  - Frontend: MATCHMADE_ROOM constant deleted, is_assigned_room removed
  - Frontend: get_current_room_queue_state removed, get_current_queue_phase no longer derives from room_queue_state
  - Frontend: RoomQueueCommand no longer uses room_phase fallback for queue ack
  - Frontend: RoomViewModelBuilder queue_status_text/queue_error_text only for match rooms, matchmade_room title removed
  - Frontend: battle_result_transition, room_selection_policy, room_session, room_session_controller use is_match_room instead of matchmade_room literal
  - room_queue_state field retained for serialization compat but frontend no longer reads it
- Owner: room-state-machine
- Last updated: 2026-04-27
- Linked tests/docs: `proto/qqt/internal/game/v1/room_control.proto`, `services/game_service/internal/rpcapi/room_control_service.go`, `services/game_service/internal/rpcapi/mapper.go`, `services/room_service/internal/gameclient/client.go`, `services/room_service/internal/roomapp/service.go`, `app/front/navigation/front_room_kind.gd`, `app/front/room/room_use_case_runtime_state.gd`, `docs/architecture/room_state_machine.md`, `docs/architecture/network_control_plane.md`

## DEBT-010 battle authority batch consumption not coalesced
- Risk level: P1
- Status: closed
- Related dirs: `network/session/runtime/`, `network/session/`, `gameplay/network/rollback/`
- Forbidden new-logic dirs: per-message authority rollback paths that bypass a batch coalescing boundary
- Planned phase: native-frame-sync-refactor
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
- Planned phase: room-protocol-closure
- Done definition: room client send and receive path use generated protobuf envelope end-to-end, room_service wsapi no longer uses hand-written protowire as formal path, snapshot projection excludes reconnect token fields
- Owner: room-protocol
- Last updated: 2026-04-19
- Linked tests/docs: `services/room_service/internal/wsapi/proto_roundtrip_test.go`, `services/room_service/internal/wsapi/ws_dispatcher_full_coverage_test.go`, `tests/contracts/runtime/room_client_runtime_no_json_path_contract_test.gd`, `tests/contracts/runtime/room_client_runtime_no_formal_transport_fallback_contract_test.gd`, `docs/architecture/room_protocol.md`

## DEBT-008 room control plane weak typed grpc
- Risk level: P1
- Status: closed
- Related dirs: `services/room_service/internal/gameclient/`, `services/game_service/internal/rpcapi/`, `proto/qqt/internal/game/v1/`
- Forbidden new-logic dirs: `services/game_service/internal/rpcapi/grpc_server.go` manual `grpc.ServiceDesc` and `structpb.Struct` formal request path
- Planned phase: room-protocol-closure
- Done definition: room_service gameclient uses generated typed grpc client, game_service rpcapi uses generated service registration and typed request and response only, room control operations pass through typed mapper
- Owner: control-plane
- Last updated: 2026-04-19
- Linked tests/docs: `services/game_service/internal/rpcapi/party_queue_rpc_test.go`, `services/game_service/internal/rpcapi/manual_room_battle_rpc_test.go`, `services/game_service/internal/rpcapi/assignment_commit_rpc_test.go`, `services/game_service/internal/rpcapi/grpc_server.go`, `docs/architecture/network_control_plane.md`

## DEBT-009 client room sdk test coverage missing
- Risk level: P1
- Status: closed
- Related dirs: `tests/csharp/QQTang.RoomClient.Tests/`, `network/client_net/room/`, `network/client_net/generated/`
- Forbidden new-logic dirs: protocol changes in `network/client_net/room/` without committed csharp tests
- Planned phase: room-protocol-closure
- Done definition: dedicated csharp test project exists in solution, envelope factory and codec and parser and snapshot mapper and canonical mapper are covered, tests run in local validation and CI entry
- Owner: client-sdk
- Last updated: 2026-04-19
- Linked tests/docs: `tests/csharp/QQTang.RoomClient.Tests/RoomClientEnvelopeFactoryTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomProtoCodecTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomServerEnvelopeParserTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomSnapshotMapperTests.cs`, `tests/csharp/QQTang.RoomClient.Tests/RoomCanonicalMessageMapperTests.cs`, `scripts/validation/run_validation.ps1`, `.github/workflows/validate.yml`


