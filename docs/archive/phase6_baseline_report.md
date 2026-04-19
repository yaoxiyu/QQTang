# Phase6 Baseline Report

> Archival note: this file is a historical Phase6 snapshot and is not current implementation truth. Current source structure and responsibilities are defined by `docs/current_source_of_truth.md`.
> Purpose: freeze the current Phase5-closeout baseline before Phase6 implementation.
> Source date: 2026-04-02
> Source of truth priority: `docs/current_source_of_truth.md`
> Archival note: this file is a **Phase6 historical snapshot**. For current implementation truth after Phase7 resource formalization, prefer `docs/current_source_of_truth.md` and the latest Phase7 documents.

## 1. Formal entry baseline

### 1.1 `res://scenes/front/room_scene.tscn`

- Root node: `RoomScene`
- Root script: `res://scenes/front/room_scene_controller.gd`
- HUD helper: `res://presentation/battle/hud/room_hud_controller.gd`
- Current UI includes:
  - launch mode selector
  - dedicated server host / port / room id inputs
  - player name / character selector
  - member list
  - ready / start controls
  - map / rule selectors
  - debug info panel

Current interpretation:

- This is already the formal client-visible room entry.
- It supports both `LOCAL_SINGLEPLAYER` and `NETWORK_CLIENT`.
- DS flow is already wired into this scene rather than a separate front-end shell.

### 1.2 `res://scenes/battle/battle_main.tscn`

- Root node: `BattleMain`
- Root script: `res://scenes/battle/battle_main_controller.gd`
- Runtime bootstrap: `res://gameplay/battle/runtime/battle_bootstrap.gd`
- Presentation bridge: `res://presentation/battle/bridge/presentation_bridge.gd`
- HUD scripts currently mounted:
  - `battle_hud_controller.gd`
  - `countdown_panel.gd`
  - `player_status_panel.gd`
  - `network_status_panel.gd`
  - `match_message_panel.gd`
- Scene controllers currently mounted:
  - `map_view_controller.gd`
  - `battle_camera_controller.gd`
  - `spawn_fx_controller.gd`
- Settlement popup scene:
  - `res://scenes/battle/settlement_popup.tscn`

Current interpretation:

- This is already the formal battle visual chain.
- Phase6 should extend startup / finish / return-room stability, not rebuild battle entry.

### 1.3 `res://scenes/network/dedicated_server_scene.tscn`

- Root node: `DedicatedServerScene`
- Root script: `res://network/runtime/dedicated_server_bootstrap.gd`
- Child roots:
  - `TransportRoot`
  - `SessionRoot`
  - `RuntimeRoot`

Current interpretation:

- This is already the formal DS process entry.
- It is minimal and correctly not a front-end UI scene.

### 1.4 `res://scenes/network/network_bootstrap_scene.tscn`

- Root node: `NetworkBootstrap`
- Root script: `res://network/runtime/network_bootstrap.gd`
- Child roots:
  - `TransportRoot`
  - `SessionRoot`
  - `DebugRoot`
  - `CanvasLayer/DebugPanel`
- Current title text:
  - `Transport Debug Shell (Not Formal Game Entry)`

Current interpretation:

- This scene is already partially labeled as debug-only.
- It still exists as a runnable transport shell and remains a likely source of future misuse if not further downgraded in Phase6.

## 2. `BattleStartConfig` baseline

File:

- `res://gameplay/battle/config/battle_start_config.gd`

### 2.1 Current serialized fields from `to_dict()`

- `protocol_version`
- `gameplay_rule_version`
- `room_id`
- `match_id`
- `map_id`
- `map_version`
- `map_content_hash`
- `rule_set_id`
- `players`
- `player_slots`
- `spawn_assignments`
- `seed`
- `start_tick`
- `match_duration_ticks`
- `item_spawn_profile_id`
- `snapshot_interval`
- `checksum_interval`
- `rollback_window`
- `session_mode`
- `topology`
- `authority_host`
- `authority_port`
- `local_peer_id`
- `controlled_peer_id`
- `owner_peer_id`
- `server_match_revision`
- `character_loadouts`

### 2.2 Current validation baseline

`BattleStartConfig.validate()` already checks:

- protocol version
- gameplay rule version
- room / match / map required fields
- map version and map content hash presence
- player slot uniqueness
- spawn assignment coverage
- topology and session mode validity
- dedicated server local/control peer constraints
- optional map metadata consistency
- character loadout coverage and peer ownership

Current gap summary:

- Validation shape is already meaningful.
- Contract semantics are still not fully explicit around candidate vs canonical config.
- Rule metadata validation is still relatively light compared with map validation.

## 3. Content registry baseline

### 3.1 Maps

Catalog file:

- `res://content/maps/catalog/map_catalog.gd`

Current registry entries:

- `default_map`
  - display name: `Default Plaza`
  - resource path: `res://content/maps/resources/map_small_square.tres`
  - default: `true`
- `large_map`
  - display name: `Cross Arena`
  - resource path: `res://content/maps/resources/map_cross_arena.tres`
- `test_square`
  - display name: `测试方形图`
  - def path: `res://gameplay/config/map_defs/square_map_def.gd`

Current output structure:

- `get_map_entries()` returns:
  - `id`
  - `display_name`
- `get_map_metadata()` currently falls back to def-script metadata only.

Loader file:

- `res://content/maps/runtime/map_loader.gd`

Current loader behavior:

- Prefers `.tres` resource loading when `resource_path` exists.
- Falls back to legacy map def script when only `def_path` exists.
- `load_map_metadata()` from `.tres` returns:
  - `map_id`
  - `display_name`
  - `version`
  - `width`
  - `height`
  - `spawn_points`
  - `item_spawn_profile_id`
  - `content_hash`
  - `resource_path`

Baseline conclusion:

- Map resource path is already the real formal direction.
- `test_square` is still present in formal catalog output and is a known Phase6 cleanup target.

### 3.2 Rules

Catalog file:

- `res://content/rules/rule_catalog.gd`

Current registry entries:

- `classic`
  - display name: `经典模式`
  - def path: `res://gameplay/config/rule_defs/classic_rule_def.gd`
  - default: `true`

Current output structure:

- `get_rule_entries()` returns:
  - `id`
  - `display_name`
- `get_rule_metadata()` loads and returns full def-script build dictionary.

Loader file:

- `res://content/rules/rule_loader.gd`

Current loader behavior:

- Script-definition only
- Validates:
  - `rule_id`
  - `display_name`
  - `round_time_sec`
  - `starting_bomb_count`
  - `starting_firepower`
  - `starting_speed`
  - `victory_mode`

Baseline conclusion:

- Rule system already has a formal catalog/loader entry.
- Metadata exposure is thinner than the map side and still mostly script-defined.

### 3.3 Characters

Catalog file:

- `res://content/characters/catalog/character_catalog.gd`

Phase6 snapshot entries:

- `hero_default`
  - display name: `Default Hero`
  - legacy compatible resource path: `res://content/characters/resources/default_hero.tres`
  - default: `true`

Current Phase7 formalized resource paths:

- `hero_default`
  - def: `res://content/characters/data/character/hero_default_def.tres`
  - stats: `res://content/characters/data/stats/hero_default_stats.tres`
  - presentation: `res://content/characters/data/presentation/hero_default_presentation.tres`

Current output structure:

- `get_character_entries()` returns:
  - `id`
  - `display_name`

Loader file:

- `res://content/characters/runtime/character_loader.gd`

Phase6 snapshot behavior:

- Loads `.tres` resource by `character_id`
- Falls back to default character if unknown id is provided
- `build_character_loadout(character_id, peer_id)` returns runtime loadout dictionary from resource

Current Phase7 behavior:

- New resource chain is preferred:
  - `CharacterDef`
  - `CharacterStatsDef`
  - `CharacterPresentationDef`
- Historical note:
  - `CharacterResource` was a temporary compatibility layer during the early Phase7 migration
  - It has been removed from the current runtime chain and must not be treated as an active dependency

Baseline conclusion:

- Character resourceization is already in place.
- Runtime currently tolerates invalid ids by silently resolving to default, which Phase6 may need to tighten earlier in room validation.

## 4. DS flow baseline

### 4.1 Client room runtime

File:

- `res://network/runtime/room_client/client_room_runtime.gd`

Current supported request flow:

1. `connect_to_server(host, port, timeout_sec)`
2. `request_create_or_join_room(room_id_hint, player_name, character_id)`
3. `request_update_profile(player_name, character_id)`
4. `request_update_selection(map_id, rule_set_id)`
5. `request_toggle_ready()`
6. `request_start_match()`
7. `send_battle_input(message)`

Current inbound message routing:

- `ROOM_JOIN_ACCEPTED`
- `ROOM_JOIN_REJECTED`
- `ROOM_SNAPSHOT`
- `JOIN_BATTLE_ACCEPTED`
- `JOIN_BATTLE_REJECTED`
- battle runtime messages:
  - `INPUT_ACK`
  - `STATE_SUMMARY`
  - `CHECKPOINT`
  - `AUTHORITATIVE_SNAPSHOT`
  - `MATCH_FINISHED`

### 4.2 Dedicated server bootstrap

File:

- `res://network/runtime/dedicated_server_bootstrap.gd`

Current behavior:

- Creates `ServerRoomService`
- Creates `ServerMatchService`
- Creates ENet server transport
- Polls transport and routes:
  - room messages to room service
  - runtime input messages to match service
- On `start_match_requested`, calls `ServerMatchService.start_match(snapshot)`

Current gap:

- No formal peer connected / peer disconnected / transport error signal wiring was found here.
- Current implementation is still message-routing focused rather than full lifecycle authority wiring.

### 4.3 Server room authority

File:

- `res://network/session/legacy/server_room_service.gd`

Current confirmed behavior:

- join request creates or joins room
- owner is determined through room state
- profile update is accepted
- selection update is owner-only
- ready toggle is supported
- start request is owner-only and gated by `room_state.can_start()`
- leave request currently maps to `handle_peer_disconnected()`
- room snapshot is broadcast after changes

Current gap:

- Owner-only rule exists here, but local room-side behavior still needs explicit parity review.
- Character / map / rule validation is still light at request entry.
- Disconnect handling is room-state only and not yet integrated with active match abort / recovery.

### 4.4 Server match authority

File:

- `res://network/session/runtime/server_match_service.gd`

Current confirmed behavior:

- uses `MatchStartCoordinator` to build canonical config
- increments `server_match_revision`
- validates start config before launch
- starts authority runtime
- duplicates canonical config per player:
  - sets `local_peer_id`
  - sets `controlled_peer_id`
- emits `JOIN_BATTLE_ACCEPTED` to each client
- advances authoritative tick in `_process`
- forwards authority runtime messages to broadcast

Current gap:

- `_on_battle_finished()` only sets `_active = false`
- no full room recovery / ready reset / snapshot restore path yet
- no explicit disconnect abort policy yet

## 5. Room controller baseline

File:

- `res://scenes/front/room_scene_controller.gd`

Current role summary:

- populates mode / map / rule / character selectors from catalogs
- binds to:
  - `AppRuntimeRoot`
  - local room controller
  - front flow
  - match coordinator
  - client room runtime
- handles both:
  - local singleplayer room creation / ready / start
  - network client connect / join / selection / ready / start
- applies authoritative room snapshot back into local room controller
- launches battle on canonical config receipt

Baseline conclusion:

- `room_scene_controller.gd` is already the formal client room orchestrator.
- It is also clearly overweight and mixes UI, local room flow, and DS runtime interaction.
- Step 2 extraction of a room client gateway is justified by current code shape.

## 6. Immediate Phase6 risks confirmed by baseline

1. Formal map catalog still exposes `test_square`.
2. `network_bootstrap_scene` is labeled debug-only in scene text, but formal downgrade is not yet fully enforced by docs and code comments.
3. Dedicated server bootstrap lacks formal peer disconnect lifecycle handling.
4. Server match finish currently stops active runtime but does not complete room recovery.
5. Room controller is handling too many DS client interaction details directly.
6. Character validity is still tolerant in loader fallback rather than enforced early at room authority boundaries.

## 7. Baseline conclusion

Current project state is already beyond prototype:

- formal room entry exists
- formal battle chain exists
- formal dedicated server entry exists
- DS join/start path exists
- content catalogs exist for map / rule / character
- `BattleStartConfig` is already a meaningful contract object

Phase6 therefore should proceed as:

- formalization
- contract hardening
- authority parity tightening
- lifecycle recovery completion
- debug shell downgrade

and not as a ground-up redesign.
