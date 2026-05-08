# map_theme_40_v1

## 定位

地图主题资源规格，覆盖地面、墙体、可破坏块、机关和装饰表现资源。

## 尺寸

```text
cell_px = 40
map_size = 15×13 cells
```

`cell_px` 是单格像素尺寸。正式地图当前只保留 `map_desert01` 和 `map_match01` 两张 `15×13` 地图。

## 地面层

地面层由 `map_floor_tiles.csv` 定义：

```csv
map_id,x,y,w,h,elem_key,expand
map_desert01,0,0,1,1,desert/elem12_stand,0
map_match01,0,0,15,13,box/elem1_stand,0
```

`x,y,w,h` 均为逻辑格单位。被引用的标准地砖图片应为 `40×40` 像素，默认归入 floor。

## 表现层

表现层由 `map_surface_instances.csv` 定义：

```csv
map_id,instance_id,elem_key,x,y,z_bias,render_role
```

`x,y` 默认是 `bottom_right` 锚点，表示表现占格右下角所在格。override 可设置 `anchor_mode=bottom_left` 或 `anchor_mode=bottom_center`。`bottom_left` 表示表现占格左下角所在格；`bottom_center` 表示底边中心所在格，`1×1` 对齐该格中心底边，`3×1` 对齐第 2 格底边，`2×1` 对齐两个格子的中线。所有非 `40×40` 资产默认表现占格 1×1、碰撞占格 1×1；有 `die` 动画的 `stand` 资产默认可破坏，有 `trigger` 动画的 `stand` 资产默认可触发，其余默认纯装饰。特殊占格、碰撞、锚点或人工逻辑例外通过 `map_elem_overrides.csv` 维护。

## 渲染排序

```text
floor:   地面层
fx:      泡泡/爆炸火焰
actor:   角色，按行排序，下方高于上方
surface: 表现层，整体高于角色
```

surface 内部排序键为：

```text
sort_key = (anchor_y, -anchor_x, z_bias)
```

渲染位置计算：

```text
draw_x = (anchor_x + 1) * cell_px - texture_width
draw_y = (anchor_y + 1) * cell_px - texture_height
```

## 校验

- 仅 `map_desert01` 和 `map_match01` 应进入正式地图目录。
- floor 必须覆盖整张 `15×13` 逻辑地图。
- surface 的表现占格和碰撞占格都按 `anchor_mode` 校验边界。
- 旧的 `map_elem_layer_config.csv`、`map_elem_footprint_overrides.csv`、实例级 footprint 列不得恢复。
