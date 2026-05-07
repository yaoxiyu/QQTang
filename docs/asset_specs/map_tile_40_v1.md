# map_tile_40_v1

## 定位

地图 Tile 资产与玩法语义规格。地图语义必须数据化，不能依赖图片名。

## 基础尺寸

```text
cell_px = 40
```

Tile 可以使用 `40x40`、`44x54`、`80x80`、`520x320` 等画布，但 footprint 必须对齐 40 像素格子。多格资产（M×N）的 footprint 由 `classify_asset()` 自动推断（图像宽高均为 40 整数倍 → `multi_cell_grid_exact`），或通过权写 CSV 手动覆盖。

## Footprint 权写

自动推断可能因非标尺寸、视觉外溢等原因出错。按优先级合并两数据源：

1. `map_elem_visual_meta.csv` 的 `footprint_w/footprint_h` 列（自动分析生成，997 行）
2. `map_elem_footprint_overrides.csv`（手动修正，增量覆盖）

```csv
# map_elem_footprint_overrides.csv
elem_key,footprint_w,footprint_h
match/elem4_stand,15,5
```

权写只修改 footprint 数值，不改变层级或逻辑类型。

## 层级配置

`classify_asset()` 硬编码规则"40×40→floor，其他→surface"不能覆盖例外（如 520×320 的 match/elem1 实际是地面）。全量层级配置由独立 CSV 表达：

```csv
# map_elem_layer_config.csv
elem_key,layer_hint
box/elem1_stand,floor       ← 40×40
match/elem1_stand,floor     ← 手动修正
match/elem4_stand,surface
```

编辑器扫描资产时优先级：`classify_asset()` → 层配置覆盖 → 逻辑类型推导 → footprint 权写覆盖。

## Surface 表现

`surface_entries` 是 Battle 地图运行期表现输入。表现字段必须数据化，不能由 controller 根据图片名猜测。

当前稳定字段：

```text
texture_path,die_texture_path,cell,footprint,anchor_mode,offset_px,z_bias,render_role,interaction_kind,logic_type
```

新增 `logic_type` 字段（取自 visual_meta），用于区分：

```text
decoration = 纯装饰，所在格子豁免地面覆盖校验
breakable  = 可破坏块，所在格子必须有地面
trigger    = 可触发机关，所在格子必须有地面
floor      = 地面本身
```

可扩展字段：

```text
fit_mode,edge_bleed_px,die_duration_sec
```

`fit_mode` 约定：

```text
source = 保持原始像素尺寸, 默认用于正式地图 surface 方块
cell_width = 等比缩放到 footprint 宽度, 仅用于非正式或占位 surface 方块
cell_size = 非等比缩放到 footprint 尺寸
original = 保持原始像素尺寸, 默认用于 occluder
```

`edge_bleed_px` 约定：

- 用于覆盖 camera 非整数缩放和 Sprite 独立采样导致的细缝。
- 正式 40px 地图资产默认不做缩放, 由原始资源相对 40px 格子的外溢覆盖相邻边。
- `cell_width` 和 `cell_size` 可允许 1px 边缘覆盖。
- `original` 默认不做边缘覆盖。
- 如特定资源不允许覆盖, 可显式设为 `0`。

die 表现约定：

- 可破坏 surface 元素销毁时播放 `die_texture_path` 指向的 die 表现。
- die 生命周期由表现组件控制, 默认只等待播放窗口后释放节点。
- 默认销毁效果不得叠加透明淡出或缩放淡出。
- 如果 die 资源需要精确帧时长, 应通过 `die_duration_sec` 或后续 SpriteFrames 数据表达, 不应在 controller 中写死。

## Surface CSV 持久化

`map_surface_instances.csv` 字段：

```csv
map_id,instance_id,elem_key,x,y,footprint_w,footprint_h,z_bias,render_role
```

`footprint_w/footprint_h` 在编辑器放置时从 AssetMeta 冻结写入。加载时优先读 CSV 存储值（防止后期 AssetMeta 变更导致占格漂移），列缺失则回退到 AssetMeta 推断。

## Floor 渲染

地面层按实例渲染：

- **多格资产**（`meta.footprint_w > 1 or meta.footprint_h > 1`）：原图整张拉伸到 `M*40 × N*40`，一次性绘制
- **普通 40×40 资产**：逐格平铺 `floor_image()`（alpha 外扩后的 40×40 tile）

`map_floor_tiles.csv` 新增 `expand` 字段：

```csv
map_id,x,y,w,h,elem_key,expand
```

- `expand=0`：引用原始资源路径，不做像素外扩（当前所有资产均为 0）
- `expand=1`：生成外扩纹理到 `content/maps/generated/floor_tiles/`，消除 tile 拼接缝

## 管线校验

- 地面覆盖校验：每格必须有 floor 或被 `logic_type=decoration` 的 surface 覆盖
- 出生点数量 = 地图人数上限（`map_resource.max_player_count = spawn_points.size()`）
- 匹配格式变体由 `spawn_count >= expected_total_player_count` 决定，非硬编码阈值
- 多格 surface 必须完全在地图边界内：`x + footprint_w <= width && y + footprint_h <= height`

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
