# 统一 Animation 规范文档
更新时间：2026-04-04 13:34

> 文档定位：本文件用于在当前 QQ 堂重置项目中，统一 **角色动画** 与 **泡泡动画** 的资源目录、生产方式、导入方式、运行期消费方式与命名规范。  
> 依据：本规范参考 `Current 角色动画资源流水线与首个角色落地` 文档中的角色动画处理思路，并结合当前泡泡资源的实际情况，补全为一套统一 animation 规范。

---

# 1. 当前项目情况与本规范的目标

根据 Current 文档，当前项目已经具备以下前提：

1. `Room -> Battle -> DS` 主链路已经建立  
2. `res://content/` 已经是正式内容真相层  
3. `res://content_source/` 已经承担内容生产源文件职责  
4. `res://tools/content_pipeline/` 已经承担 CSV -> `.tres` 的生产职责  
5. 角色主体动画在 Current 被明确要求从“占位几何体表现”升级为“正式动画资源流水线”  
6. 当前泡泡资源也已经进入内容系统，不应继续停留在临时图片直连阶段

因此，本规范的目标是：

- 统一角色与泡泡动画的**源文件目录**
- 统一角色与泡泡动画的**导入参数**
- 统一角色与泡泡动画的**切帧规则**
- 统一角色与泡泡动画的**运行期消费方式**
- 统一角色与泡泡动画的**CSV / 内容定义 / catalog / runtime builder** 思路
- 保证后续新增角色或泡泡动画时，**不需要修改核心脚本**

---

# 2. 总体设计原则

所有 animation 资产统一遵循以下原则：

## 2.1 源图片不是运行期真相

源图片只放在：

```text
res://assets/animation/
```

运行期正式真相应是：

- `.tres` 内容定义
- `SpriteFrames`
- runtime config / presentation config

Battle / Room / HUD 不应直接硬编码图片路径。

## 2.2 角色动画与泡泡动画都要走正式内容层

角色动画应建立：

```text
res://content/character_animation_sets/
```

泡泡动画建议建立：

```text
res://content/bubble_animation_sets/
```

角色与泡泡都不应只靠“在脚本里 load 某张 png”来驱动。

## 2.3 统一使用 SpriteFrames 2D 作为首版正式运行期格式

Godot 4.6 中，当前项目最稳的 2D 像素动画运行期格式统一为：

- `AnimatedSprite2D`
- `SpriteFrames`

原因：

- 易导入
- 易调试
- 适合像素风
- 和当前项目的四方向角色、循环泡泡都高度兼容
- 不会把复杂骨骼系统提前引进来增加维护成本

## 2.4 源图片可多样，生成后的运行期格式统一

允许的源图片形式：

- 角色：四方向 strip png
- 泡泡：4x4 grid / 单 strip / 单帧序列

但生成后统一转换为：

- 可稳定导入 Godot 的 `SpriteFrames`
- 内容层 `.tres`
- 可被 presentation 层稳定消费的 animation set

---

# 3. 统一目录规范

## 3.1 源图片目录

角色源图片目录：

```text
res://assets/animation/characters/<character_group>/
```

示例：

```text
res://assets/animation/characters/huoying/char_red_down.png
res://assets/animation/characters/huoying/char_red_left.png
res://assets/animation/characters/huoying/char_red_right.png
res://assets/animation/characters/huoying/char_red_up.png
```

泡泡源图片目录：

```text
res://assets/animation/bubbles/<bubble_style>/
```

首个普通泡泡建议固定为：

```text
res://assets/animation/bubbles/normal/bubble_normal_grid.png
res://assets/animation/bubbles/normal/bubble_normal_loop.png
res://assets/animation/bubbles/normal/frames/bubble_normal_00.png
...
res://assets/animation/bubbles/normal/frames/bubble_normal_15.png
```

## 3.2 内容定义目录

角色动画内容定义目录：

```text
res://content/character_animation_sets/defs/
res://content/character_animation_sets/data/sets/
res://content/character_animation_sets/generated/sprite_frames/
res://content/character_animation_sets/catalog/
```

泡泡动画内容定义目录建议新增：

```text
res://content/bubble_animation_sets/defs/
res://content/bubble_animation_sets/data/sets/
res://content/bubble_animation_sets/generated/sprite_frames/
res://content/bubble_animation_sets/catalog/
```

## 3.3 内容生产源目录

角色动画 CSV：

```text
res://content_source/csv/character_animation_sets/character_animation_sets.csv
```

泡泡动画 CSV 建议新增：

```text
res://content_source/csv/bubble_animation_sets/bubble_animation_sets.csv
```

---

# 4. 角色动画规范

## 4.1 角色源图片标准

当前项目已验证的角色样本采用：

- 四方向各一张 strip
- 每张 strip 为横向排列
- 每张 strip 内有固定帧数
- 当前首个角色样本为：
  - `400 x 100`
  - 单帧 `100 x 100`
  - 每方向 `4` 帧

## 4.2 角色运行期动画名规范

统一要求生成以下动画名：

```text
idle_down
idle_left
idle_right
idle_up
run_down
run_left
run_right
run_up
dead_down
dead_left
dead_right
dead_up
```

即使当前首版只真正拥有 run strip，也要在生成期补出 idle / dead 的最小占位动画，以保证运行期接口稳定。

## 4.3 角色表现消费标准

`CharacterPresentationDef` 中应引用：

- `animation_set_id`
- `body_view_type`

推荐：

- `body_view_type = "sprite_frames_2d"`

Battle 中的正式角色 body view 应使用：

- `AnimatedSprite2D`
- `SpriteFrames`

而不是继续使用 `Polygon2D` 占位图形。

---

# 5. 泡泡动画规范

## 5.1 泡泡资源的当前情况

本次提供的普通泡泡图像具有以下特征：

- 图像尺寸：`256 x 256`
- 布局：`4 x 4`
- 总帧数：`16`
- 单帧尺寸：`64 x 64`
- 适合做单循环的 idle / hover / shimmer 动画

这和角色动画不同：

- 角色动画是四方向 strip
- 泡泡动画通常不需要方向分支
- 泡泡动画更像一个单循环视觉动画集

## 5.2 泡泡源图片标准

推荐源图片支持以下两种形式：

### 形式 A：grid 图

```text
4 x 4
8 x 2
2 x 8
```

适合从素材站获取的单图格子资源。

### 形式 B：horizontal strip 图

```text
1 x N
```

适合已经过流水线整理后的项目内标准格式。

当前普通泡泡样本已经整理出这两个版本：

- `bubble_normal_grid.png`
- `bubble_normal_loop.png`

## 5.3 泡泡运行期动画名规范

泡泡首版统一使用以下动画名：

```text
idle
```

后续如果新增特殊状态，再扩展：

```text
spawn
idle
warning
burst
```

但当前普通泡泡首版不需要过度设计，先固定为 `idle`。

## 5.4 泡泡播放参数建议

普通泡泡建议：

- `fps = 10`
- `loop = true`
- `idle_frame_index = 0`

如果未来出现警戒泡泡或即将爆炸泡泡，再基于单独动画集扩展，不要在当前普通泡泡资源上硬塞特殊逻辑。

---

# 6. 导入参数统一规范（Godot 4.6）

所有像素风 animation png 统一使用以下 Import 参数：

```text
Filter = Off
Mipmaps = Off
Repeat = Disabled
Compression = Lossless
```

原因：

- 防止像素糊边
- 防止采样抖动
- 保持像素风稳定
- 避免 UI / 角色动画在缩放时模糊

---

# 7. 切帧规则统一规范

## 7.1 角色切帧

角色 strip 统一要求：

- 每张方向图只对应一个方向
- 方向图内部横向切帧
- `frame_width` / `frame_height` 由 CSV 显式记录
- `frames_per_direction` 由 CSV 显式记录

## 7.2 泡泡切帧

泡泡 grid / strip 统一要求：

- 运行期统一转成横向 strip 或直接生成 `SpriteFrames`
- `frame_width` / `frame_height` 明确记录
- 总帧数记录为 `frame_count`
- 泡泡 animation set 不需要方向字段

---

# 8. 内容定义建议

## 8.1 角色动画内容定义

已在 Current 中确立：

```gdscript
CharacterAnimationSetDef
- animation_set_id
- display_name
- sprite_frames
- frame_width
- frame_height
- frames_per_direction
- run_fps
- idle_frame_index
- pivot
- loop_run
- loop_idle
- content_hash
```

## 8.2 泡泡动画内容定义建议新增

建议新增：

```text
res://content/bubble_animation_sets/defs/bubble_animation_set_def.gd
```

字段建议：

```gdscript
extends Resource
class_name BubbleAnimationSetDef

@export var animation_set_id: String = ""
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames
@export var frame_width: int = 0
@export var frame_height: int = 0
@export var frame_count: int = 0
@export var idle_fps: float = 10.0
@export var idle_frame_index: int = 0
@export var loop_idle: bool = true
@export var content_hash: String = ""
```

说明：

- 泡泡没有方向，因此不需要 `frames_per_direction`
- 泡泡首版也不需要复杂 pivot 系统
- 但需要稳定的 `SpriteFrames`、帧尺寸和循环参数

---

# 9. CSV 规范

## 9.1 角色动画 CSV

延续 Current 文档中建议的：

```text
animation_set_id,
display_name,
down_strip_path,
left_strip_path,
right_strip_path,
up_strip_path,
frame_width,
frame_height,
frames_per_direction,
run_fps,
idle_frame_index,
pivot_x,
pivot_y,
loop_run,
loop_idle,
content_hash
```

## 9.2 泡泡动画 CSV 建议

建议新增：

```text
animation_set_id,
display_name,
source_layout_type,
source_image_path,
frame_width,
frame_height,
frame_count,
source_columns,
source_rows,
idle_fps,
idle_frame_index,
loop_idle,
content_hash
```

当前普通泡泡样例可写为：

```text
bubble_anim_normal,普通泡泡,grid,res://assets/animation/bubbles/normal/bubble_normal_grid.png,64,64,16,4,4,10,0,true,<hash>
```

如果改用整理后的横向 strip，则可写为：

```text
bubble_anim_normal,普通泡泡,strip,res://assets/animation/bubbles/normal/bubble_normal_loop.png,64,64,16,16,1,10,0,true,<hash>
```

---

# 10. Generator 规范

## 10.1 角色动画 Generator

沿用 Current 思路：

```text
res://tools/content_pipeline/generators/generate_character_animation_sets.gd
```

职责：

- 读取角色动画 CSV
- 解析四方向 strip
- 生成 `SpriteFrames`
- 生成 `CharacterAnimationSetDef.tres`
- 输出到 generated / data

## 10.2 泡泡动画 Generator 建议新增

建议新增：

```text
res://tools/content_pipeline/generators/generate_bubble_animation_sets.gd
```

职责：

- 读取泡泡动画 CSV
- 支持 grid / strip 两种源布局
- 生成 `SpriteFrames`
- 生成 `BubbleAnimationSetDef.tres`

核心要求：

- 不允许 Battle 里手工拼帧
- 不允许每个泡泡样式手工点击 Godot 编辑器做 `.tres`
- 首版普通泡泡也必须走正式 generator

---

# 11. Catalog 规范

角色动画 catalog：

```text
res://content/character_animation_sets/catalog/character_animation_set_catalog.gd
```

泡泡动画 catalog 建议新增：

```text
res://content/bubble_animation_sets/catalog/bubble_animation_set_catalog.gd
```

共同原则：

- 自动扫描目录
- `get_by_id()`
- `has_id()`
- `get_all()`
- 明确报重复 id
- 明确报空 id

---

# 12. Runtime 消费规范

## 12.1 角色

角色在 Battle 中应通过：

- `CharacterPresentationDef.animation_set_id`
- `CharacterAnimationSetCatalog.get_by_id()`
- `CharacterSpriteBodyView`

完成动画加载。

## 12.2 泡泡

泡泡在 Battle 中建议通过：

- `BubbleStyleDef.animation_set_id` 或新增 `bubble_animation_set_id`
- `BubbleAnimationSetCatalog.get_by_id()`
- `BubbleSpriteView`

完成动画加载。

如果当前 `BubbleStyleDef` 尚无该字段，建议在后续阶段新增：

```gdscript
@export var animation_set_id: String = ""
```

---

# 13. 命名规范

## 13.1 角色

资源命名统一：

```text
char_<theme>_<color>_<direction>.png
char_anim_<theme>_<color>.tres
char_anim_<theme>_<color>_frames.tres
```

示例：

```text
char_red_down.png
char_anim_huoying_red.tres
char_anim_huoying_red_frames.tres
```

## 13.2 泡泡

资源命名统一：

```text
bubble_<style>_grid.png
bubble_<style>_loop.png
bubble_anim_<style>.tres
bubble_anim_<style>_frames.tres
```

示例：

```text
bubble_normal_grid.png
bubble_normal_loop.png
bubble_anim_normal.tres
bubble_anim_normal_frames.tres
```

---

# 14. 当前普通泡泡的建议落地方式

基于本次上传资源，当前普通泡泡建议按以下方式落地：

## 14.1 目录

```text
res://assets/animation/bubbles/normal/bubble_normal_grid.png
res://assets/animation/bubbles/normal/bubble_normal_loop.png
```

## 14.2 运行期动画集 id

```text
bubble_anim_normal
```

## 14.3 播放参数

```text
fps = 10
loop = true
animation_name = "idle"
```

## 14.4 首版不做的内容

当前普通泡泡首版暂不做：

- warning 动画
- 爆炸前闪烁特殊状态
- 不同威力等级差异动画
- 材质驱动的高级发光

这些后续在泡泡系统扩展时再加，不要污染首版流水线。

---

# 15. 统一实施顺序建议

后续所有 animation 资产都按这个顺序推进：

## Step 1
放置源图片到 `res://assets/animation/...`

## Step 2
补充 CSV 条目

## Step 3
运行 generator

## Step 4
生成 `SpriteFrames` 与 animation set `.tres`

## Step 5
catalog 自动扫描

## Step 6
presentation / actor view 消费 animation set

## Step 7
Room -> Battle 链路验证

---

# 16. 最终结论

当前项目的 animation 体系不应该再分裂成“角色一套、泡泡一套、每次都手工做”的状态。  
正确方向是：

- **角色动画**：走 `character_animation_sets`
- **泡泡动画**：走 `bubble_animation_sets`
- **源图片**：统一放在 `res://assets/animation/`
- **生产入口**：统一走 CSV
- **生成产物**：统一落成 `SpriteFrames + AnimationSetDef`
- **运行期消费**：统一通过 catalog + presentation view

这样后面无论你是继续加：

- 新角色
- 新泡泡
- 新皮肤
- 新爆炸动画
- 新地图机关动画

都能在同一套 pipeline 上继续扩，而不会再回到“临时导图片 + 手工点编辑器”的返工模式。

---

```text
 /\_/\\
( •ω• )
/ >🎞️ 统一规范完成喵
```

