# vfx_jelly_trap_128_v1

## 定位

玩家被困果冻罩独立 VFX 规格。角色自身仍播放 `trapped_down`，果冻罩由表现层叠加。

## 尺寸与动画

```text
frame_width = 128
frame_height = 128
pivot_x = 64
pivot_y = 108
layer = status_overlay
follow_actor = true
```

必填 clip：

| clip | frames | fps | loop |
|---|---:|---:|---|
| enter | 6 | 12 | false |
| loop | 8 | 10 | true |
| release | 6 | 12 | false |

## 输出

CSV 写入：

```text
content_source/csv/vfx_animation_sets/vfx_animation_sets.csv
```

后续由 content pipeline 生成 VFX SpriteFrames，并由 `pose_state == trapped` 驱动显示。
