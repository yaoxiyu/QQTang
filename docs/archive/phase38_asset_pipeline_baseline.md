# Phase38 资产流水线基线

本文记录 Phase38 开始前仓库内已经存在的资产与内容链路。Phase38 只在现有链路上增加上游资产工厂，不替换当前 `content_source/csv -> content -> presentation` 的正式路径。

## 角色动画链路

当前角色动画源表：

```text
content_source/csv/character_animation_sets/character_animation_sets.csv
```

当前字段：

```text
animation_set_id,display_name,down_strip_path,left_strip_path,right_strip_path,up_strip_path,frame_width,frame_height,frames_per_direction,run_fps,idle_frame_index,pivot_x,pivot_y,pivot_adjust_x,pivot_adjust_y,loop_run,loop_idle,trapped_down_strip_path,victory_down_strip_path,defeat_down_strip_path,content_hash
```

当前生成器：

```text
tools/content_pipeline/generators/generate_character_animation_sets.gd
```

生成输出：

```text
content/character_animation_sets/data/sets/
content/character_animation_sets/generated/sprite_frames/
```

运行期入口：

```text
content/character_animation_sets/catalog/
content/character_animation_sets/runtime/
presentation/battle/actors/
```

现有规格以 `100x100`、四方向、每方向 4 帧为基线，并已经包含 `trapped_down`、`victory_down`、`defeat_down` 特殊姿态字段。

## 泡泡动画链路

当前泡泡动画源表：

```text
content_source/csv/bubble_animation_sets/bubble_animation_sets.csv
```

当前字段：

```text
animation_set_id,display_name,source_layout_type,source_image_path,frame_width,frame_height,frame_count,source_columns,source_rows,idle_fps,idle_frame_index,loop_idle,content_hash
```

当前生成器：

```text
tools/content_pipeline/generators/generate_bubble_animation_sets.gd
```

默认规格是 `64x64`、`4x4 grid`、16 帧 `idle` 循环。

## 地图与 Tile 链路

当前地图与 Tile 源表包括：

```text
content_source/csv/maps/maps.csv
content_source/csv/maps/map_match_variants.csv
content_source/csv/map_themes/map_themes.csv
content_source/csv/tile_presentations/tile_presentations.csv
```

当前 TileDef：

```text
content/tiles/defs/tile_def.gd
```

字段包括：

```text
tile_id,display_name,tile_type,scene_path,is_walkable,is_breakable,blocks_blast,blocks_movement,break_fx_id,content_hash
```

当前显示格子尺寸来自：

```text
gameplay/shared/world_metrics.gd
```

Phase38 后续会把横向穿过、纵向穿过、完全穿过等语义数据化，但必须由仿真读取 Tile 数据，不能由表现层根据贴图或文件名决定通行。

## 队伍色与被困状态

Room 与 Battle view state 已经有 `team_id` / `color` 概念，但角色动画集尚未按 team_id 选择队伍色变体。Phase38 需要新增确定性队伍色变体生成与运行期 resolver。

被困状态已经能进入表现层 pose 语义，当前角色动画包含 `trapped_down`。Phase38 需要将果冻罩拆成独立 VFX 内容资产，而不是画死到每个角色动画里。

## Phase38 扩展边界

Phase38 新增上游：

```text
content_source/asset_intake/
tools/asset_pipeline/
docs/asset_specs/
```

下游仍然保持：

```text
content_source/csv/
tools/content_pipeline/
content/
presentation/
```

禁止 runtime 直接消费 `content_source/asset_intake/`，禁止 AI 或人工手写 `.tres` 作为正式产物。
