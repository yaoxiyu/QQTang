# map_tile_40_v1

## 定位

地图 Tile 资产与玩法语义规格。地图语义必须数据化，不能依赖图片名或旧链路推断。

## 基础尺寸

```text
cell_px = 40
```

`40×40` 表示单个逻辑格子的像素尺寸，不表示地图格子数量。当前正式地图保留 `15×13` 逻辑格规格。

## 默认分类

烘焙脚本只保留一套规则：

- 图片尺寸恰好为 `40×40`：默认 `floor`，占 1×1 格，碰撞 0×0。
- 其它所有图片：默认 `surface`，表现占格 1×1，碰撞占格 1×1。
- surface 中有 `die` 动画的 `stand` 资产：默认 `breakable`。
- surface 中有 `trigger` 动画的 `stand` 资产：默认 `trigger`。
- 其它 surface：默认 `decoration`。
- surface 默认使用 `bottom_right` 锚点，`x,y` 表示右下角所在逻辑格。少数资源可在 override 中设置 `bottom_left` 或 `bottom_center`。`bottom_left` 表示左下角所在格；`bottom_center` 表示底边中心所在格，`1×1` 对齐该格中心底边，`3×1` 对齐第 2 格底边，`2×1` 对齐两个格子的中线。

不再从图片宽高自动推导多格 footprint，不再读取旧的 layer config 或实例级 footprint。

## Override 表

特殊资产只允许通过人工维护的 `content_source/csv/maps/map_elem_overrides.csv` 覆盖。常规 `breakable` / `trigger` 不需要写入 override，除非需要人工强制改逻辑类型。

```csv
elem_key,footprint_w,footprint_h,collision_w,collision_h,logic_type,anchor_mode
match/elem4_stand,15,5,0,0,decoration,bottom_left
```

字段语义：

| 字段 | 说明 |
|------|------|
| `footprint_w/h` | 表现占格，单位是 40px 逻辑格 |
| `collision_w/h` | 碰撞占格，单位是 40px 逻辑格，仍从右下角向左上扩展 |
| `logic_type` | 可选，`floor` / `decoration` / `breakable` / `trigger`，用于非 40×40 地面或其它人工逻辑例外 |
| `anchor_mode` | 可选，`bottom_right` / `bottom_left` / `bottom_center`；为空时默认 `bottom_right` |

override 只由人工维护，烘焙脚本不会自动生成特殊规则。

## Surface CSV

`map_surface_instances.csv` 字段固定为：

```csv
map_id,instance_id,elem_key,x,y,z_bias,render_role
```

占格、碰撞和逻辑类型一律来自 `map_elem_visual_meta.csv`，而 `map_elem_visual_meta.csv` 由默认规则叠加 override 生成。

## Floor CSV

`map_floor_tiles.csv` 字段：

```csv
map_id,x,y,w,h,elem_key,expand
```

`x,y,w,h` 都是逻辑格单位。正式地图每个逻辑格必须被 floor 覆盖，当前地图尺寸为 `15×13`。

## 层级规则

运行时深度分层：

```text
surface > character > bubble/explosion > floor
```

同类角色按行排序：下方角色层级高于上方角色。

## 校验

- 地图逻辑尺寸必须与资源配置一致。
- floor 覆盖必须完整覆盖地图所有逻辑格。
- surface 表现占格和碰撞占格都必须按 `anchor_mode` 不越界。
- 非纯装饰 surface 必须落在已有 floor 覆盖上。
- 表现层不得决定通行结果，通行由逻辑类型和碰撞占格共同决定。
