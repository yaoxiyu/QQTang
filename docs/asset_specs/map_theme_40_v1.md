# map_theme_40_v1

## 定位

地图主题资源规格，覆盖地面、背景、墙体、可破坏块和遮挡物表现资源。

## 尺寸

默认格子：

```text
cell_px = 40
```

地图 grid 支持 13×13（及以下）和 15×13 两种规格。编辑器默认 15×13。

多格资产尺寸约束：

```text
asset_width  = footprint_w * cell_px
asset_height = footprint_h * cell_px
```

设计时建议原始图像尺寸恰好为格子整数倍，避免编辑器内缩放失真。如 match/elem1（520×320 = 13×8）完美对齐。

大地图必须满足：

```text
background_width = width_cells * cell_px
background_height = height_cells * cell_px
```

## 地面层（Floor）

地面层由 `map_floor_tiles.csv` 定义，每条记录覆盖一个矩形区域：

```csv
map_id,x,y,w,h,elem_key,expand
map_classic_square,0,0,15,13,box/elem1_stand,0
map_match01,1,4,13,8,match/elem1_stand,0
```

字段语义：

| 字段 | 类型 | 说明 |
|------|------|------|
| `x,y` | int | 左上角格子坐标 |
| `w,h` | int | 宽度和高度（格子数），此区域用 elem_key 资产填充 |
| `elem_key` | string | 资产标识，格式 `主题/文件名`，如 `box/elem1_stand` |
| `expand` | 0/1 | 0=引用原始资源；1=管线生成 alpha 外扩纹理到 `content/maps/generated/floor_tiles/` |

资产层级由 `map_elem_layer_config.csv` 配置：40×40 资产→floor，其他→surface（可手动修正例外）。

## 表现层（Surface）

由 `map_surface_instances.csv` 定义：

```csv
map_id,instance_id,elem_key,x,y,footprint_w,footprint_h,z_bias,render_role
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `x,y` | int | 放置锚点（bottom_center 锚点以此为底边中心） |
| `footprint_w,h` | int | 占格宽高，编辑器放置时冻结写入 |
| `z_bias` | int | 渲染排序偏置 |

锚点模式：

```text
bottom_center             = 图像底部中心对齐锚点格子底边（默认，用于 tall/deco 资产）
bottom_left_of_footprint  = 图像左下角对齐 footprint 左下角（多格 grid-exact 资产）
```

`bottom_center` 资产的 `dy` 使用 `inst.footprint_h * cell_px` 做底边对齐，保证多格 tall 资产（如 1×9）的渲染与占格预览一致。

逻辑类型：

```text
decoration = 纯装饰，不参与玩法，不要求下方有地面
breakable  = 可破坏，必须有 die 纹理或 die 变体
trigger    = 可触发机关
floor      = 地面
```

## 编辑器渲染规则

```text
floor:     多格→原图拉伸 M*40×N*40; 普通 40×40→逐格平铺 floor_image
surface:   按 row_asc_col_desc_z_bias 排序后 bottom_center / bottom_left_of_footprint 锚点渲染
sort_key = (inst.y + footprint_h - 1, -inst.x, z_bias)
```

## 校验

- 背景尺寸必须匹配地图格子尺寸。
- 所有 tile presentation 必须有 scene 或 texture。
- 地图 layout 中所有符号必须有 tile 映射。
- 出生点不能落在阻挡格。
- 非纯装饰 surface 所在格必须有地面覆盖。
- 多格 surface 的 footprint 不得越界。
