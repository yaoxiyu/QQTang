# map_tile_48_v1

## 定位

地图 Tile 资产与玩法语义规格。地图语义必须数据化，不能依赖图片名。

## 基础尺寸

```text
cell_px = 48
```

Tile 可以使用 `48x48`、`48x64`、`96x96` 等画布，但 footprint 必须对齐 48 像素格子。

## Surface 表现

`surface_entries` 是 Battle 地图运行期表现输入。表现字段必须数据化，不能由 controller 根据图片名猜测。

当前稳定字段：

```text
texture_path,die_texture_path,cell,footprint,anchor_mode,offset_px,z_bias,render_role,interaction_kind
```

可扩展字段：

```text
fit_mode,edge_bleed_px,die_duration_sec
```

`fit_mode` 约定：

```text
cell_width = 等比缩放到 footprint 宽度, 默认用于普通 surface 方块
cell_size = 非等比缩放到 footprint 尺寸
original = 保持原始像素尺寸, 默认用于 occluder
```

`edge_bleed_px` 约定：

- 用于覆盖 camera 非整数缩放和 Sprite 独立采样导致的细缝。
- `cell_width` 和 `cell_size` 默认允许 1px 边缘覆盖。
- `original` 默认不做边缘覆盖。
- 如特定资源不允许覆盖, 可显式设为 `0`。

die 表现约定：

- 可破坏 surface 元素销毁时播放 `die_texture_path` 指向的 die 表现。
- die 生命周期由表现组件控制, 默认只等待播放窗口后释放节点。
- 默认销毁效果不得叠加透明淡出或缩放淡出。
- 如果 die 资源需要精确帧时长, 应通过 `die_duration_sec` 或后续 SpriteFrames 数据表达, 不应在 controller 中写死。

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
