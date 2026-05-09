# QQTang 分层角色资源整理与运行时方案

## 结论

`QQTang5.2_Beta1Build1/data/object` 中的角色资源应按“源素材分层、构建期烘焙、运行时消费成品”的方式接入项目。不要把 `body/cloth/hair/face/leg/cap/adorn` 这些目录直接暴露给战斗运行时，也不要要求所有源素材都补齐四方向后才能落地。

核心策略：

- 源素材保持分层：按部件、动作、方向、帧序列整理。
- 构建期负责合成：把可用部件按角色装配表合成成运行时动画。
- 运行时只加载角色表现包：战斗侧只关心角色表现 id、动作、朝向和可播放动画，不关心源文件来自 PNG 还是 GIF。
- 缺方向不阻断导入：先记录实际存在的方向，播放时按明确规则降级。

## 源资源事实

当前资源目录中与角色相关的高价值目录包括：

```text
body
head
face
mouth
hair
cloth
leg
foot
cap
fhadorn
thadorn
cladorn
```

命名模式大体为：

```text
<part><source_id>_<action>_<direction>.<ext>
<part><source_id>_<action>.<direction>.<ext>
```

示例：

```text
cloth10101_walk_0.gif
cloth10101_stand_3.png
body1_walk_2.gif
hair10101_stand_1.png
```

字段含义：

| 字段 | 含义 |
| --- | --- |
| `part` | 部件类型，例如 `cloth`、`hair`、`face` |
| `source_id` | 部件或角色资源 id，不保证全部等于角色 id |
| `action` | 动作名，例如 `stand`、`walk`、`cry`、`win`、`lose`、`die` |
| `direction` | QQTang 原始方向编号 |
| `ext` | `.png` 为单帧，`.gif` 为多帧动画源 |

已确认的源方向映射：

| 源方向编号 | 语义 | 项目方向名 |
| --- | --- | --- |
| `0` | 右 | `right` |
| `1` | 背对玩家 | `up` |
| `2` | 左 | `left` |
| `3` | 面对玩家 | `down` |

注意：项目当前 `PlayerState.FacingDir` 为 `UP=0, DOWN=1, LEFT=2, RIGHT=3`，不能直接拿源方向编号当运行时 facing 使用。源方向编号只在资源导入和烘焙阶段出现，烘焙后必须转换为项目方向名。

## 数据模型

### 源部件资产

新增源资产索引，建议生成到 `content_source/object_manifest/parts.csv`：

```csv
part,source_id,action,source_direction,project_direction,source_path,frame_width,frame_height,frame_count,source_format,content_hash
cloth,10101,walk,0,right,C:/.../object/cloth/cloth10101_walk_0.gif,100,100,4,gif,...
cloth,10101,stand,3,down,C:/.../object/cloth/cloth10101_stand_3.png,100,100,1,png,...
```

这个索引用于回答三个问题：

- 哪个部件 id 有哪些动作。
- 每个动作实际有哪些方向。
- 每个方向有多少帧、源格式是什么。

### 角色装配表

新增角色装配表，建议放在 `content_source/csv/characters/character_assemblies.csv`：

```csv
character_id,assembly_id,body_id,cloth_id,leg_id,foot_id,head_id,hair_id,face_id,mouth_id,npack_id,cap_id,fhadorn_id,thadorn_id,cladorn_id,default_palette_id,tags
10101,10101,1,10101,10101,1,1,10101,10101,,,"10101",,,default,resource
```

设计原因：

- `body1`、`foot1` 这类公共资源不应硬编码进代码。
- `cloth10101`、`hair10101` 等部件 id 虽然常与角色 id 一致，但不能依赖这种偶然性。
- 后续如果支持换装、换色或皮肤，只需要扩展装配表，不需要改战斗逻辑。

### 烘焙输出表现包

新增运行时资源定义，建议从现有 `CharacterAnimationSetDef` 演进为更通用的 `CharacterMotionSetDef`，或在短期内扩展当前定义：

```gdscript
@export var animation_set_id: String = ""
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames
@export var frame_width: int = 100
@export var frame_height: int = 100
@export var available_actions: PackedStringArray = []
@export var available_directions_by_action: Dictionary = {}
@export var direction_fallbacks: Dictionary = {}
@export var pivot_origin: Vector2 = Vector2(50, 100)
@export var pivot_adjust: Vector2 = Vector2(0, -15)
@export var source_assembly_id: String = ""
@export var content_hash: String = ""
```

`SpriteFrames` 动画名统一使用：

```text
<project_action>_<project_direction>
```

示例：

```text
idle_down
idle_right
run_left
cry_down
victory_down
defeat_down
dead_down
```

动作映射建议：

| QQTang 源动作 | 项目动作 | 说明 |
| --- | --- | --- |
| `stand` | `idle` | 原地待机 |
| `walk` | `run` | 移动播放 |
| `die` | `dead` | 死亡/倒下 |
| `cry` | `trapped` 或 `cry` | 需要美术确认语义；短期可用于被困或失败 |
| `win` | `victory` | 胜利 |
| `lose` | `defeat` | 失败 |
| `wait` | `idle_alt` | 可选待机变体 |
| `faint` | `stunned` | 可选眩晕/受击 |
| `sit` | `sit` | 非战斗展示 |
| `slow` | `slow` | 减速状态，可选 |
| `birth` | `spawn` | 入场/出生 |

## 分层合成

建议的默认合成顺序：

```text
body
leg
foot
cloth
head
hair
face
mouth
cap
cladorn
thadorn
fhadorn
```

合成规则：

- 所有源帧按 `100x100` 原画布直接叠加到 `(0, 0)`。
- PNG 单帧按 1 帧处理。
- GIF 解码为 RGBA 帧序列，保留透明通道。
- 同一动作、同一方向下，各部件帧数不一致时，以主部件帧数为基准。
- 主部件优先级：`cloth` > `body` > 第一个存在的部件。
- 从属部件帧数不足时使用 `frame_index % part_frame_count`。
- 部件缺动作时允许降级，例如 `face.walk` 缺失时使用 `face.stand`。
- 部件缺方向时允许按方向降级规则取替代方向。

## 缺方向策略

缺方向是源资源事实，不能在导入阶段当错误处理。每个动作应记录实际存在的方向，例如：

```json
{
  "idle": ["down", "left", "right"],
  "run": ["down", "left", "right", "up"],
  "victory": ["down"]
}
```

运行时播放请求按以下顺序解析：

1. 精确动作 + 精确方向：`run_right`。
2. 同动作方向 fallback：例如 `run_up -> run_down`。
3. 同方向动作 fallback：例如 `run_right -> idle_right`。
4. 默认正面：`idle_down`。
5. 该动画集第一条可用动画。

默认方向 fallback：

```text
right -> right, down, left, up
left  -> left, down, right, up
up    -> up, down, left, right
down  -> down, right, left, up
```

这样可以满足“先只做有的方向”的要求。后续确认某些资源本来只有正面展示时，只需要把对应动作标记为 `single_direction`，不用改播放代码。

## 运行时加载逻辑

运行时边界应保持简单：

```text
CharacterLoader
  -> CharacterPresentationDef
  -> CharacterMotionSetLoader / CharacterAnimationSetLoader
  -> CharacterBodyView
  -> SpriteFrames
```

战斗状态只传这些信息：

- `character_id`
- `animation_set_id`
- `pose_state`
- `facing`
- `move_state`
- `anim_move_x / anim_move_y`

战斗运行时不读取：

- `data/object`
- GIF
- 部件 id
- 装配表
- 调色板源规则

这样能保证网络同步和回放稳定：同步的是逻辑状态，不是美术装配细节。

## 换色策略

换色建议放在烘焙期：

- 第一阶段：只烘焙默认色，替换当前占位动画。
- 第二阶段：提取可换色区域，按队伍色或皮肤色生成多套 `animation_set_id_team_XX`。
- 第三阶段：如果确认灰色框架是可换色 mask，再建立 `palette_id + mask_layer` 的离线重着色规则。

不建议运行时 shader 换色作为第一方案，原因：

- 分层部件多，运行时 shader 参数同步成本高。
- 不同部件是否可换色还没完全确认。
- 现有项目已有 team animation resolver，更适合消费离线变体。

## 迁移步骤

### 阶段 1：资源盘点

生成 `parts.csv` 和资源报告：

- 统计每个 `part/source_id/action/direction` 是否存在。
- 记录尺寸、帧数、格式、hash。
- 标记重复文件，例如 `_stand_0.png` 与 `_stand.0.png`。
- 标记项目角色缺失资源，例如当前直接缺 `18811 / 23001 / 27101`。

当前扫描入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/scan_object_resources.ps1 -SourceRoot "res\object"
```

外部提取目录只作为一次性导入来源。被 manifest 引用到的源文件需要先镜像到项目本地 `res/object/`，并保持 `object` 下的相对目录结构；`res/` 是本地素材缓存目录，不提交到 Git。

输出：

```text
content_source/object_manifest/parts.csv
content_source/object_manifest/character_coverage.csv
content_source/object_manifest/summary.json
```

### 阶段 2：装配表

先用启发式生成 `character_assemblies.csv`：

- `cloth/hair/face/leg` 优先取角色 id。
- `body/foot/head` 使用公共 id。
- `cap/adorn/mouth` 有则填，无则空。

生成后用人工抽查 5 到 10 个角色校正层级和部件归属。

当前生成入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/generate_character_assemblies.ps1
```

输出：

```text
content_source/csv/characters/character_assemblies.csv
```

### 阶段 3：默认动作烘焙

先只烘焙：

```text
stand -> idle
walk  -> run
die   -> dead
win   -> victory
lose  -> defeat
cry   -> trapped 或 cry
faint -> stunned
trigger -> trigger
wait -> wait
```

每个动作只输出实际存在方向，不强制四方向。

当前第一版烘焙入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/bake_layered_characters.ps1
```

输出：

```text
assets/animation/characters/layered/<character_id>/*.png
assets/animation/characters/layered/layered_bake_manifest.csv
```

层级配置：

```text
content_source/csv/characters/character_layer_rules.csv
```

字段含义：

```text
direction,variant,layer_order,part,enabled,notes
```

- `direction=*` 表示默认层级。
- `direction=up/down/left/right` 表示方向覆盖；烘焙时同一个 `part` 优先使用当前方向覆盖，否则回退到 `*` 默认层级。
- `variant=` 空值表示普通层，`variant=m` 表示 `_m` 层；普通层和 `_m` 层都参与同一套 `layer_order` 排序。
- `layer_order` 越小越早绘制，越容易被后续层覆盖。
- `part` 必须对应装配表中的 `<part>_id` 字段，例如 `cloth -> cloth_id`、`npack -> npack_id`。

当前总结出的默认层级：

```text
100  body
101  body_m
200  head
201  head_m
300  face
301  face_m
400  mouth
401  mouth_m
500  hair
501  hair_m
600  leg
601  leg_m
700  foot
701  foot_m
800  cloth
801  cloth_m
850  npack
851  npack_m
900  cap
901  cap_m
1000 cladorn
1001 cladorn_m
1100 thadorn
1101 thadorn_m
1200 fhadorn
1201 fhadorn_m
```

方向特例：

```text
down npack   50    # 面对玩家时在最下层
down npack_m 51
up   npack   1300  # 背对玩家时在最上层
up   npack_m 1301
```

烘焙策略：

- 默认 `merged` 版同时取普通层和 `_m` 层，并按 `character_layer_rules.csv` 的 `layer_order` 排序绘制。
- 不再保留单独 `_m` 对比输出目录，当前只维护 `assets/animation/characters/layered`。
- 身体基础层先绘制，衣服和装饰后绘制；实际顺序由 `character_layer_rules.csv` 决定。
- `npack` 是 `object/npack` 下的附加显示层，当前参与 `10101`、`10301`、`10601` 的 `stand/walk` 拼接。
- 烘焙帧数取参与层中的最大帧数，避免 `npack` 这类动画层被静态 cloth 主层截断。
- `idle`、`run` 输出四方向：`right/up/left/down`。
- `dead`、`victory`、`defeat`、`cry`、`stunned`、`trigger`、`wait`、`spawn` 暂按正面 `down` 输出。
- 单方向特殊动作只使用该动作真实存在的部件层，不再用 `stand` 的四方向头脸、四肢等部件补层。
- `merged` 版特殊动作在 `_m` 覆盖后，会把普通层中 `_m` 透明区域的像素补回，用于保留眼泪、气泡、动作特效等非换色区域。
- 对于 `defeat/dead` 的眼泪，优先从同角色 `faint` 普通层的脸部带补回蓝色眼泪像素；`faint` 顶部星星区域不参与补像素，避免把眩晕星星混入失败/死亡动画。
- `<=12201` 的角色默认标记为 `regular_colorable`，12201 之后默认标记为 `monster_or_boss`；怪物或 Boss 缺少某个动作时直接跳过，不用 `stand` 强行补出该动作。
- 若某个角色 id 只在 `body` 目录存在直接资源、没有同 id 的 `cloth` 资源，则按 `transform_body/body_only` 处理；这类变身角色以 `body` 作为主部件烘焙，不拼公共 body/head/leg/foot。
- 11001、11101 以及 12201 之后有 `cloth` 直接资源的角色按 `cloth_only` 处理，不拼公共 body/head/leg/foot。
- 不再把缺少专属腿部资源的角色 fallback 到公共 `leg1`。idle/run 下方圆圈来自公共腿部资源 `leg1_stand.gif` / `leg1_stand_m.gif`，不是独立 ring/light 源文件。
- 目前不直接改 `character_animation_sets.csv`，先保留为可人工验收的独立烘焙产物。

### 阶段 4：运行时适配

扩展 `CharacterSpriteBodyView` 的动画解析：

- 不再假设四方向都存在。
- 使用 `available_directions_by_action` 和 fallback。
- 保持 `PlayerState.FacingDir` 不变，仅在资源层做方向名转换。

### 阶段 5：替换当前占位资源

将 `char_anim_<id>` 从占位 `11001` strip 切换到烘焙输出。

## 风险

- 源资源方向编号与运行时 facing 编号不同，必须在导入层转换，不能混用。
- 部件层级需要人工校验，尤其是帽子、前后饰品、脸和头发。
- GIF 解码要确认透明帧 dispose 行为，否则会出现残影。
- 缺方向需要显式报告，避免长期被 fallback 掩盖。
- 如果后续要保留完整换装能力，需要把装配表作为可配置内容，而不是一次性烘焙后丢弃。
