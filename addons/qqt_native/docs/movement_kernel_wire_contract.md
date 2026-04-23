# Movement Kernel Wire Contract

## Purpose
Define the packed input/output contract for `QQTNativeMovementKernel.step_players(input_blob)`.

This contract is Phase30 shadow-path only:
- GDScript remains the orchestration owner.
- Native consumes packed batch input and returns packed batch results.
- No Node/Scene/Resource references cross the bridge.

## Encoding Container

`input_blob` and `result_blob` are `PackedByteArray` values encoded from a top-level `Dictionary`.

Top-level input dictionary keys:
- `version`
- `player_records`
- `bubble_records`
- `blocked_grid_records`
- `command_records`
- `tuning`

Top-level result dictionary keys:
- `version`
- `result_records`
- `cell_changed_records`
- `ignore_remove_records`
- `blocked_event_records`

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

### Result Record Stride

Array key:
- `result_records`

Stride:
- `10`

Per-record layout:
1. `player_id`
2. `new_cell_x`
3. `new_cell_y`
4. `new_offset_x`
5. `new_offset_y`
6. `new_facing`
7. `new_move_state`
8. `new_move_phase_ticks`
9. `blocked`
10. `turn_only`

Rules:
- `blocked` and `turn_only` are `0/1`.
- One result record per input player record.
- Output order must match input player record order exactly.

### Cell Changed Record Stride

Array key:
- `cell_changed_records`

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

### Ignore Remove Record Stride

Array key:
- `ignore_remove_records`

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

### Blocked Event Record Stride

Array key:
- `blocked_event_records`

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
