# character_sprite_100_v1

## 定位

角色 2D Sprite strip 规格，兼容当前角色内容生成器。

## 尺寸与动画

```text
frame_width = 100
frame_height = 100
frames_per_direction = 4
run_fps = 8
idle_frame_index = 0
pivot_x = 50
pivot_y = 100
pivot_adjust_x = 0
pivot_adjust_y = -15
```

必填 clip：

```text
down,left,right,up,trapped_down,victory_down,defeat_down
```

每个源图必须是横向 strip，宽度为 `400`，高度为 `100`，PNG RGBA 透明背景。

## 输出

CSV 写入：

```text
content_source/csv/character_animation_sets/character_animation_sets.csv
```

content pipeline 生成：

```text
content/character_animation_sets/data/sets/
content/character_animation_sets/generated/sprite_frames/
```

## 校验

- 必填文件存在。
- PNG 可读取且带 alpha。
- 尺寸等于 `400x100`。
- 非透明像素不为空。
- `animation_set_id` 不重复。
- 正式写 CSV 前 `rights.commercial_use == true` 且 `rights.review_status == approved`。
