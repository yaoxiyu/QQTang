# map_tile_48_v1

## 定位

地图 Tile 资产与玩法语义规格。地图语义必须数据化，不能依赖图片名。

## 基础尺寸

```text
cell_px = 48
```

Tile 可以使用 `48x48`、`48x64`、`96x96` 等画布，但 footprint 必须对齐 48 像素格子。

## Tile 语义

方向 mask：

```text
N = 1
E = 2
S = 4
W = 8
ALL = 15
HORIZONTAL = 10
VERTICAL = 5
NONE = 0
```

必须支持：

```text
floor,solid_wall,breakable_block,horizontal_pass,vertical_pass,all_pass_overlay,occluder,spawn,mechanism
```

建议字段：

```text
tile_category,movement_pass_mask,blast_pass_mask,is_walkable,is_breakable,blocks_movement,blocks_blast,can_spawn_item,occlusion_mode
```

## 校验

- Tile 类型必须能映射到明确语义。
- 横向/纵向通行必须由 mask 表达。
- 表现层不得决定通行结果。
