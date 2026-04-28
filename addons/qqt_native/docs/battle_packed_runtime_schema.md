# Battle Packed Runtime Schema

Current introduces this schema as the formal packed wire contract between GDScript battle runtime code and `qqt_native` kernels.

The current Dictionary/Variant codec remains for parity and regression testing. New native hot-path work should prefer this schema and direct stride access.

## Version

```text
SCHEMA_VERSION = 1
```

Every packed state must carry the schema version in both the top-level payload and the header array.

## Payload Shape

```text
BattlePackedState
  schema_version: int
  header: PackedInt32Array
  players: PackedInt32Array
  bubbles: PackedInt32Array
  items: PackedInt32Array
  grid: PackedInt32Array
  events: PackedInt32Array
```

## Units

- `cell`: integer tile coordinate.
- `subcell`: fixed-point position inside the simulation grid.
- `tick`: integer simulation tick.
- `hash`: stable signed 31-bit hash generated from string IDs.

## Header Layout

```text
HEADER_STRIDE = 8

0 schema_version
1 tick_id
2 map_width
3 map_height
4 player_count
5 bubble_count
6 item_count
7 grid_cell_count
```

## Player Layout

```text
PLAYER_STRIDE = 16

0  player_id_hash
1  team_id_hash
2  x_subcell
3  y_subcell
4  dir
5  state
6  alive
7  trapped
8  move_speed_subcell
9  bomb_capacity
10 fire_power
11 active_bubble_count
12 input_seq
13 checksum_salt
14 reserved0
15 reserved1
```

## Bubble Layout

```text
BUBBLE_STRIDE = 12

0  bubble_id_hash
1  owner_player_id_hash
2  x_cell
3  y_cell
4  fire_power
5  state
6  placed_tick
7  explode_tick
8  chain_triggered
9  style_id_hash
10 reserved0
11 reserved1
```

## Item Layout

```text
ITEM_STRIDE = 8

0 item_id_hash
1 item_type_hash
2 x_cell
3 y_cell
4 state
5 spawn_tick
6 reserved0
7 reserved1
```

## Grid Layout

```text
GRID_STRIDE = 4

0 cell_type
1 blocker_flags
2 occupant_flags
3 reserved0
```

## Compatibility

Reserved fields may receive meaning in later schema revisions, but existing fields must not be reordered or retyped inside `SCHEMA_VERSION = 1`.

Breaking changes require a new schema version and explicit adapter support on both the GDScript and C++ sides.

## Migration Policy

Current does not require replacing all simulation objects with structure-of-arrays data. The intended migration path is:

1. Keep current `WorldSnapshot` and simulation objects.
2. Build packed state through `NativeBattlePackedStateBuilder`.
3. Let future native kernels consume packed arrays by schema constants.
4. Keep the old Dictionary codec only as an explicit parity/regression path.

