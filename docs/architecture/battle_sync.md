# Battle Sync Architecture

> Current source of truth for dedicated-server battle frame sync runtime boundaries and performance risks.  
> Last updated: 2026-04-24.

## Positioning

Battle sync is currently **GDScript orchestration with selected GDExtension kernels**.

GDScript owns the sync control plane:

- transport queueing and project-level message encoding,
- runtime message routing,
- DS authoritative tick scheduling,
- client input timing,
- authoritative message ingestion,
- prediction and rollback decisions,
- rollback replay scheduling.

Native code owns selected compute/storage kernels:

- movement calculation,
- explosion propagation,
- checksum,
- packed snapshot payload codec,
- snapshot ring storage.
- authority batch coalescing.

Detailed state ownership and `STATE_SUMMARY` / `CHECKPOINT` rules are in [`../battle_sync_rule_audit.md`](../battle_sync_rule_audit.md).

## Current Local Sync Changes

### Opening Input Freeze

Dedicated-server start configs now include:

- `opening_input_freeze_ticks`
- `network_input_lead_ticks`

Default values for dedicated-server topology:

```text
opening_input_freeze_ticks = 2 * TickRunnerScript.TICK_RATE
network_input_lead_ticks = 3
```

During the opening freeze:

- clients poll DS authority messages and refresh the predicted/presentation world;
- clients do not build or send local input;
- DS rejects any input that still arrives during the freeze;
- DS emits one freeze-end log with dropped input count.

Purpose:

- prevent local movement prediction before the first stable DS authority state;
- give loading handoff, first checkpoint, opening animation, voice, and countdown a deterministic input-free buffer.

Touched code:

- `gameplay/battle/config/battle_start_config.gd`
- `network/session/runtime/battle_start_config_builder.gd`
- `network/session/runtime/authority_runtime.gd`
- `network/session/battle_session_network_gateway.gd`

### Input Lead

Client input target tick now resolves from both local prediction and latest authority:

```text
target_tick >= latest_authoritative_tick + network_input_lead_ticks
```

This reduces the chance that input is sent for a tick the DS is already simulating.

Touched code:

- `network/session/runtime/client_runtime.gd`

Current limitation:

- the lead is a fixed heuristic; it should eventually be derived from measured RTT/jitter and clamped by a max prediction window.

### Late Input Policy

DS now retargets late input frames:

```text
if frame.tick_id <= authority_tick:
    frame.tick_id = authority_tick + 1
```

This prevents slightly late movement input from silently becoming a dead historical frame.

Current limitation:

- this is a stopgap. Final movement handling should be seq-driven per peer, with bounded lateness, stale-seq drops, and aggregated metrics.

### Log Flood Reduction

Per-packet, per-message, per-tick, and per-player presentation debug logs are default-off. `rollback_probe` and `rollback_resync` are info-level instead of warning-level to avoid warning backtrace flood.

Touched code:

- `network/transport/enet_battle_transport.gd`
- `network/session/runtime/runtime_message_router.gd`
- `presentation/battle/bridge/presentation_bridge.gd`
- `presentation/battle/bridge/state_to_view_mapper.gd`
- `presentation/battle/actors/player_actor_view.gd`
- `network/session/runtime/client_runtime.gd`

## GDScript Boundary

Still in GDScript:

- ENet wrapper and JSON project message codec:
  - `network/transport/enet_battle_transport.gd`
  - `network/transport/transport_message_codec.gd`
- Message routing:
  - `network/session/runtime/runtime_message_router.gd`
- DS authority runtime:
  - `network/session/runtime/authority_runtime.gd`
  - `network/session/runtime/server_match_service.gd`
  - `network/session/runtime/battle_match.gd`
- Client runtime:
  - `network/session/runtime/client_runtime.gd`
  - `network/session/battle_session_network_gateway.gd`
- Prediction and rollback:
  - `gameplay/network/prediction/prediction_controller.gd`
  - `gameplay/network/rollback/rollback_controller.gd`
- Input buffers:
  - `gameplay/simulation/input/input_buffer.gd`
  - `gameplay/simulation/input/input_ring_buffer.gd`
- Simulation orchestration:
  - `gameplay/simulation/runtime/sim_world.gd`
  - `gameplay/simulation/runtime/system_pipeline.gd`

Implication:

- authority batch consumption has a native execute path;
- input timing policy, snapshot diff, rollback planning, and battle message codec have native execute paths with shadow checks still enabled;
- high-level runtime routing and rollback replay scheduling remain GDScript-owned.

## Native Boundary

Registered native classes:

- `QQTNativePackedStateCodec`
- `QQTNativeChecksumBuilder`
- `QQTNativeSnapshotRing`
- `QQTNativeMovementKernel`
- `QQTNativeExplosionKernel`
- `QQTNativeAuthorityBatchCoalescer`
- `QQTNativeInputBuffer`
- `QQTNativeSnapshotDiff`
- `QQTNativeRollbackPlanner`
- `QQTNativeBattleMessageCodec`

Registration:

- `addons/qqt_native/src/register_types.cpp`

Native-backed paths:

- checksum:
  - `gameplay/native_bridge/native_checksum_bridge.gd`
  - `addons/qqt_native/src/checksum/native_checksum_builder.*`
- snapshot ring:
  - `gameplay/simulation/snapshot/snapshot_buffer.gd`
  - `addons/qqt_native/src/snapshot/native_snapshot_ring.*`
- snapshot codec:
  - `gameplay/native_bridge/native_packed_state_codec_bridge.gd`
  - `addons/qqt_native/src/codec/native_packed_state_codec.*`
- movement:
  - `gameplay/simulation/systems/movement_system.gd`
  - `gameplay/native_bridge/native_movement_bridge.gd`
  - `addons/qqt_native/src/movement/native_movement_kernel.*`
- explosion:
  - `gameplay/simulation/systems/explosion_resolve_system.gd`
  - `gameplay/native_bridge/native_explosion_bridge.gd`
  - `addons/qqt_native/src/explosion/native_explosion_kernel.*`
- authority batch coalescer:
  - `network/session/runtime/authority_batch_coalescer.gd`
  - `gameplay/native_bridge/native_authority_batch_bridge.gd`
  - `addons/qqt_native/src/sync/native_authority_batch_coalescer.*`
- input buffer and late input policy shadow:
  - `gameplay/simulation/input/input_buffer.gd`
  - `network/session/runtime/authority_runtime.gd`
  - `gameplay/native_bridge/native_input_buffer_bridge.gd`
  - `addons/qqt_native/src/sync/native_input_buffer.*`
- snapshot diff and rollback planner shadow:
  - `gameplay/network/rollback/rollback_controller.gd`
  - `gameplay/native_bridge/native_snapshot_diff_bridge.gd`
  - `gameplay/native_bridge/native_rollback_planner_bridge.gd`
  - `addons/qqt_native/src/sync/native_snapshot_diff.*`
  - `addons/qqt_native/src/sync/native_rollback_planner.*`
- battle message codec shadow:
  - `network/transport/transport_message_codec.gd`
  - `addons/qqt_native/src/sync/native_battle_message_codec.*`

## Authority Message Consumption Risk

Legacy client consumption path before Phase32:

1. `ENetBattleTransport.poll()` drains all available packets.
2. `consume_incoming()` returns the batch.
3. `RuntimeMessageRouter.route_messages()` dispatches messages in order.
4. `ClientRuntime.ingest_network_message()` handles every message immediately.
5. Each `CHECKPOINT` / `AUTHORITATIVE_SNAPSHOT` can immediately trigger rollback/resync.
6. Presentation is emitted after the poll cycle.

Risk:

- if multiple authority snapshots arrive in one poll, rollback can run multiple times for intermediate snapshots;
- this creates CPU spikes and correction churn after network stalls;
- presentation often sees only the final world, but rollback already paid the cost for each intermediate authority frame.

Tracked as:

- `DEBT-010 battle authority batch consumption not coalesced`

## Authority Batch Boundary

Phase32 adds a client poll batch boundary before runtime ingestion:

```text
consume_incoming()
  -> route non-authority messages through RuntimeMessageRouter
  -> coalesce INPUT_ACK / STATE_SUMMARY / CHECKPOINT / AUTHORITATIVE_SNAPSHOT / MATCH_FINISHED
  -> ClientRuntime.ingest_authority_batch()
  -> at most one latest useful authority snapshot reaches rollback
```

Implemented paths:

- GDScript baseline:
  - `network/session/runtime/authority_batch_coalescer.gd`
- Native shadow/execute bridge:
  - `gameplay/native_bridge/native_authority_batch_bridge.gd`
  - `addons/qqt_native/src/sync/native_authority_batch_coalescer.*`
- Runtime batch API:
  - `network/session/runtime/client_runtime.gd`
- Poll boundary:
  - `network/session/battle_session_network_gateway.gd`

Current coalescing semantics:

- keep max `INPUT_ACK` per peer;
- keep latest `STATE_SUMMARY`;
- keep latest non-stale `CHECKPOINT` / `AUTHORITATIVE_SNAPSHOT`;
- drop stale and intermediate authority snapshots before rollback;
- preserve authority events by tick;
- apply `MATCH_FINISHED` after coalesced authority state.

Native authority batch coalescer is enabled with shadow still on:

```text
enable_native_authority_batch_coalescer = true
enable_native_authority_batch_coalescer_shadow = true
enable_native_authority_batch_coalescer_execute = true
```

Native input buffer is enabled in execute mode with shadow checks:

```text
enable_native_input_buffer = true
enable_native_input_buffer_shadow = true
enable_native_input_buffer_execute = true
```

Implemented paths:

- `addons/qqt_native/src/sync/native_input_buffer.*`
- `gameplay/native_bridge/native_input_buffer_bridge.gd`

Current scope:

- native buffer mirrors normal `InputBuffer` push/merge/fallback/ack behavior through adapter shadow;
- native late input policy is implemented and covered by metrics tests;
- `AuthorityRuntime` records native late-policy shadow decisions;
- authority runtime uses native late-policy execute mode and records shadow comparison metrics.

Rollback switch:

```text
enable_native_input_buffer_execute = false
```

Reason:

- disables native late-policy execution and falls back to GDScript late retarget behavior.

Native snapshot diff and rollback planner are enabled in execute mode with shadow checks:

```text
enable_native_snapshot_diff = true
enable_native_snapshot_diff_shadow = true
enable_native_snapshot_diff_execute = true
enable_native_rollback_planner = true
enable_native_rollback_planner_shadow = true
enable_native_rollback_planner_execute = true
```

Current scope:

- `RollbackController.describe_snapshot_diff()` returns the native diff when execute mode is enabled;
- native diff and planner metrics are recorded through `get_native_rollback_shadow_metrics()`;
- rollback replay still uses the existing GDScript restore/replay loop.

Native battle message codec is enabled in execute mode:

```text
enable_native_battle_message_codec = true
enable_native_battle_message_codec_shadow = true
enable_native_battle_message_codec_execute = true
```

Current scope:

- native binary payloads are the default project message wire format;
- JSON decode remains accepted for compatibility and rollback.

## Next Architecture Step

After Phase32, remaining extraction candidates are:

- rollback replay loop,
- peer compatibility rollout for mixed JSON/native-codec clients,
- deeper production profiling for rollback replay cost.

Avoid first extracting high-level `ClientRuntime`, `AuthorityRuntime`, or router glue while those paths are still Dictionary-heavy.

## Verification

Latest GDScript syntax gate after the sync code changes:

```powershell
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
```

Result:

```text
[gdsyntax] PASS checked=757
[gdsyntax] syntax preflight passed
```
