# bubble_animation_64_v1

## 定位

泡泡 idle 动画规格，兼容当前泡泡内容生成器。

## 尺寸

```text
frame_width = 64
frame_height = 64
frame_count = 16
source_columns = 4
source_rows = 4
idle_fps = 10
idle_frame_index = 0
loop_idle = true
```

默认源图为 `256x256` PNG RGBA grid。

## 输出

CSV 写入：

```text
content_source/csv/bubble_animation_sets/bubble_animation_sets.csv
```

content pipeline 生成 `idle` SpriteFrames。

## 校验

- `layout.type` 只能是 `grid` 或 `strip`。
- grid 宽高必须匹配列数、行数和帧尺寸。
- `frame_count <= columns * rows`。
- 正式写 CSV 前必须通过商业授权门禁。
