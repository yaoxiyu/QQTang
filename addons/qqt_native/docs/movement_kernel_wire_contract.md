# Movement Kernel Wire Contract

## Purpose
Define the packed input/output contract for `QQTNativeMovementKernel.step_players_packed(...)` and the compatibility `step_players(input_blob)` entry point.

This contract is Phase30 mainline native execution:
- GDScript remains the orchestration owner.
- Native consumes packed batch input and returns packed batch results.
- No Node/Scene/Resource references cross the bridge.
- The compatibility `step_players(input_blob)` path accepts the same binary layout below. Older top-level Dictionary payloads are retained only for explicit compatibility tests.

## Encoding Container

`step_players_packed(...)` receives packed arrays directly:

- `players: PackedInt32Array`
- `bubbles: PackedInt32Array`
- `ignore_values: PackedInt32Array`
- `blocked_grid: PackedInt32Array`
- `movement_step_units: int`
- `turn_snap_window_units: int`
- `pass_absorb_window_units: int`

The compatibility `input_blob` uses little-endian signed 32-bit integers:

1. magic `QQTM`
2. wire version
3. `movement_step_units`
4. `turn_snap_window_units`
5. `pass_absorb_window_units`
6. `player_records` length, then values
7. `bubble_records` length, then values
8. `bubble_ignore_values` length, then values
9. `blocked_grid_records` length, then values

Top-level result dictionary keys:
- `version`
- `player_updates`
- `cell_changes`
- `bubble_ignore_removals`
- `blocked_events`

Current wire version:
- `1`

## Input Strides

### Player Record Stride

Array key:
- `player_records`

Stride:
- `16`

Per-record layout:
1. `player_id`
2. `player_slot`
3. `alive`
4. `life_state`
5. `cell_x`
6. `cell_y`
7. `offset_x`
8. `offset_y`
9. `last_non_zero_move_x`
10. `last_non_zero_move_y`
11. `facing`
12. `move_state`
13. `move_phase_ticks`
14. `speed_level`
15. `command_move_x`
16. `command_move_y`

Rules:
- `alive` is encoded as `0/1`.
- `command_move_x/y` must already be sanitized to single-axis input in bridge logic.
- Record ordering must be stable and match the `player_ids` batch order passed by the bridge.

### Bubble Record Stride

Array key:
- `bubble_records`

Stride:
- `6`

Per-record layout:
1. `bubble_id`
2. `alive`
3. `cell_x`
4. `cell_y`
5. `ignore_count`
6. `ignore_values_offset`

Rules:
- `alive` is encoded as `0/1`.
- `ignore_values_offset` points into a separate flattened ignore array owned by the bridge payload.
- Ignore values must preserve current authoritative order.
- Native uses these records only for overlap-ignore refresh and lane blocking checks.

### Blocked Grid Stride

Array key:
- `blocked_grid_records`

Stride:
- `5`

Per-record layout:
1. `cell_x`
2. `cell_y`
3. `tile_block_move`
4. `bubble_id`
5. `rail_mask_reserved`

Rules:
- One record per cell in `y-major -> x-major` order.
- `tile_block_move` is `0/1`.
- `bubble_id` is `-1` when no bubble occupies the cell.
- `rail_mask_reserved` is reserved for future precomputed lane metadata; Phase30 writes `0`.

## Output Strides

### Player Updates

Array key:
- `player_updates`

Each entry is a dictionary with:

- `player_id`
- `cell_x`
- `cell_y`
- `offset_x`
- `offset_y`
- `facing`
- `move_state`
- `move_phase_ticks`
- `last_non_zero_move_x`
- `last_non_zero_move_y`

Rules:
- `blocked` and `turn_only` are `0/1`.
- One result record per input player record.
- Output order must match input player record order exactly.

### Cell Changes

Array key:
- `cell_changes`

Stride:
- `5`

Per-record layout:
1. `player_id`
2. `from_cell_x`
3. `from_cell_y`
4. `to_cell_x`
5. `to_cell_y`

Rules:
- Emit only when foot cell actually changes.
- Order must match player processing order.

### Bubble Ignore Removals

Array key:
- `bubble_ignore_removals`

Stride:
- `2`

Per-record layout:
1. `bubble_id`
2. `player_id`

Rules:
- Emit one record for each `(bubble_id, player_id)` pair removed from `ignore_player_ids`.
- Order must be stable:
  1. player processing order
  2. then bubble id ascending within that player pass

## Additional Output Records

### Blocked Events

Array key:
- `blocked_events`

Stride:
- `5`

Per-record layout:
1. `player_id`
2. `from_cell_x`
3. `from_cell_y`
4. `blocked_cell_x`
5. `blocked_cell_y`

Rules:
- Emit only when movement ends in blocked state for that tick.
- Order must match player processing order.

## Determinism Rules

- Native must not depend on unordered container iteration.
- All booleans are encoded as integers.
- All coordinates and offsets are integer fixed-point values.
- Grid traversal stays `y-major -> x-major`.
- Result ordering must be fully deterministic for identical input blobs.

## Phase30 Boundary Notes

- This contract is intentionally coarse-grained to avoid high-frequency GDScript/native round trips.
- GDScript bridge remains responsible for:
  - packing state
  - unpacking results
  - writing back `PlayerState`
  - emitting `SimEvent`
  - updating `ctx.state.indexes`
- Native remains responsible only for batch movement hot-loop computation.
