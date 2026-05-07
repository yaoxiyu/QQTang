# map_theme_40_v1

## 定位

地图主题资源规格，覆盖地面、背景、墙体、可破坏块和遮挡物表现资源。

## 尺寸

默认格子：

```text
cell_px = 40
```

13x11 地图 full background：

```text
520x440
```

大地图必须满足：

```text
background_width = width_cells * cell_px
background_height = height_cells * cell_px
```

## 校验

- 背景尺寸必须匹配地图格子尺寸。
- 所有 tile presentation 必须有 scene 或 texture。
- 地图 layout 中所有符号必须有 tile 映射。
- 出生点不能落在阻挡格。
