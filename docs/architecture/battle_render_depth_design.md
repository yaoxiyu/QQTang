# 战斗渲染深度、通道与飞机投送设计

## 背景

当前战斗表现层已经形成了一个方向正确的深度模型：世界对象不依赖 Godot 的 `YSort`，而是通过 `BattleDepth` 计算绝对 `z_index`。这套方案对网络同步、回放和调试是有利的，因为同一份仿真状态可以确定性映射到同一份表现排序。

但随着地图 surface、通道、飞机投送、飞行掉落物和更多 FX 接入，深度规则开始出现局部手写值和补偿逻辑。典型例子是飞机使用 `row_y * 100 + 1000`，飞行中的掉落物使用 `max_row * 100 + 500`，玩家又通过 surface 行缓存抬高。它们的意图是对的，但需要沉淀成正式契约，否则后续加新特效会继续扩散魔法数。

本文目标是定义一套工程化的战斗渲染深度设计，覆盖地图、角色、泡泡、爆炸、道具、飞机投送、飞行中道具、通道隐藏与调试验证。

## 当前代码事实

渲染深度核心入口在 `presentation/battle/battle_depth.gd`。当前公式为：

```gdscript
z = cell.y * ROW_STEP + layer_priority * WITHIN_ROW_STEP - cell.x + z_bias
```

其中 `ROW_STEP = 100`，`WITHIN_ROW_STEP = 10`，当前行内优先级大致为：

```text
fx      = 1
actor   = 2
surface = 3
```

战斗场景结构在 `scenes/battle/battle_main.tscn`：

```text
BattleMain
  WorldRoot
    EnvironmentRoot
    MapRoot
      GroundLayer
      SurfaceLayer
      StaticBlockLayer
      BreakableBlockLayer
    ActorLayer
    OccluderLayer
    FxLayer
    DebugLayer
  CanvasLayer
```

运行时 `scenes/battle/battle_main_controller.gd` 会将 `CanvasLayer.layer = -1`，并将 `WorldRoot.z_index = 1000`。这意味着战斗世界会压过普通 HUD CanvasLayer，调试层另建高层 CanvasLayer。这个策略是现状的一部分，后续改动必须显式评估 HUD 与战斗世界的关系。

地图表现真相在 `presentation/battle/scene/map_view_controller.gd`。内容管线将 `map_surface_instances.csv` 与 `map_elem_visual_meta.csv` 生成 `MapRuntimeLayout.surface_entries`，其中包含：

```text
cell
footprint
collision_footprint
anchor_mode
z_bias
render_role
interaction_kind
movement_pass_mask
sort_key = Vector3i(y, -x, z_bias)
```

surface 节点最终由 `MapSurfaceElementView` 设置：

```gdscript
z_as_relative = false
z_index = BattleDepth.surface_z(cell, z_bias)
```

## 飞机投送现状理解

最新提交 `165168e8 fly drop` 新增了飞机投送逻辑。核心链路如下：

```text
ItemPoolRuntime
  保存 recycle_pool、airplane_timer_ticks、airplane_active、airplane_x、airplane_y
  可被标准快照 capture/restore

ItemPoolSystem
  回收池有物品时按 interval 生成飞机
  飞机从右侧外进入，airplane_x 逐 tick 减少
  飞行中按冷却从 recycle_pool 消耗一个 battle_item
  查找可落点后生成 ItemState
  将 item.scatter_from_x/y 设置为飞机当前位置

StateToViewMapper
  将 scatter_from_x/y 转为世界坐标，传给 ItemActorView

ItemActorView
  如果 scatter_from 存在，播放二次贝塞尔飞行动画
  飞行中保持特殊高 z
  落地后恢复 BattleDepth.item_z(cell)

PresentationBridge
  根据 item_pool_runtime.airplane_active 创建/更新 AirplaneActorView
```

当前飞机 z 逻辑在 `presentation/battle/actors/airplane_actor_view.gd`：

```gdscript
z_index = row_y * 100 + 1000
```

当前飞行中掉落物 z 逻辑在 `presentation/battle/actors/item_actor_view.gd`：

```gdscript
var max_row := maxi(int(from.y / cell_size_px), int(to.y / cell_size_px))
z_index = max_row * 100 + 500
```

这两个值的本质不是普通行内层级，而是“空中深度带”：

```text
普通行内对象：row * 100 + 0..99
飞行中道具：max_path_row * 100 + 500
飞机：airplane_row * 100 + 1000
```

因此飞机投送的 z 要求可以理解为：

```text
飞机必须在战斗世界对象之上，表现为高空飞过。
飞行中掉落物必须高于飞越路径附近的 surface/actor/fx。
飞行中掉落物必须低于飞机，保持投送关系。
掉落物落地后必须回到普通道具地面深度。
```

这个语义应进入 `BattleDepth`，不应继续留在 actor 脚本中手写。

## 通道现状理解

通道不是纯表现层概念，而是内容、仿真、表现三层共同协议。

内容层来源是 `content_source/csv/maps/map_channel_instances.csv`：

```csv
map_id,x,y,movement_pass_dirs,allow_place_bubble
map_bun01,3,2,udlr,true
```

内容管线在 `tools/content_pipeline/generators/generate_maps.gd` 将 `movement_pass_dirs` 解析成 bit mask：

```text
u/n = 1
r/e = 2
d/s = 4
l/w = 8
udlr = 15
none = 0
```

运行时 `content/maps/runtime/map_loader.gd` 将 `channel_entries` 应用到 `GridState`：

```gdscript
static_cell.movement_pass_mask = movement_pass_mask
static_cell.allow_place_bubble = allow_place_bubble
```

如果 `movement_pass_mask == PASS_ALL`，会清掉 `TILE_BLOCK_MOVE`。如果是 `PASS_NONE`，会设置 `TILE_BLOCK_MOVE`。如果是方向性 mask，例如 `PASS_VERTICAL` 或 `PASS_HORIZONTAL`，则主要由 transition 判定控制方向通行。

仿真查询在 `gameplay/simulation/queries/sim_queries.gd`：

```gdscript
is_transition_tile_blocked(from, to):
  from_cell 必须允许朝目标方向出去
  to_cell 必须允许从反方向进入
```

也就是说通道是双向边约束，而不是单格简单可走/不可走。角色移动、轨道约束和泡泡放置会使用这份静态格语义。

表现层在 `BattleMapViewController` 预计算 `_channel_pass_mask_by_cell`，再由 `PresentationBridge` 传入 `ActorRegistry`，最终作用于：

```text
PlayerActorView
  接近 channel 中心时 hide_body_sprite
  跨连接边时保持隐藏，减少边缘闪烁
  channel 重叠时参考 surface_render_z_by_cell 抬高 z

BubbleActorView
  如果泡泡 cell 在 channel 中，隐藏泡泡 sprite
```

因此通道的表现需求是：

```text
玩家进入通道时，身体视觉可隐藏或被遮罩。
玩家在连接通道边界移动时，隐藏状态不能闪烁。
泡泡位于通道 cell 时不应露在通道覆盖物上。
通道 cell 的 z 修正要服务于遮挡，不改变仿真移动权威。
```

## 设计原则

1. `BattleDepth` 是唯一世界深度入口。
2. 所有世界对象默认使用 `z_as_relative = false`。
3. 子部件可以使用相对 z，但只能在父对象内部排序，例如角色身体、队伍标记、状态特效。
4. 飞机与飞行中掉落物使用正式的 airborne 深度带，而不是手写魔法数。
5. 通道分为移动语义、放置语义、表现遮挡语义，三者共享数据但不互相替代。
6. 地图 surface 遮挡应逐步从整行最大值改为局部 footprint 查询。
7. 每个特殊深度决策都必须能在 debug 模式中解释 reason。

## 实施边界

本设计默认只允许修改战斗渲染深度、战斗表现层、通道表现策略、飞机投送表现和对应测试。不得为了实现渲染层级优化而修改任何其它不相关流程的代码，尤其不得影响登录、房间、匹配、加载、结算、音频、账号服务、网络协议和非战斗 UI 流程。

如果实现过程中发现必须触碰其它流程，必须先给出明确说明，不能直接改。说明至少包含：

```text
必须修改的位置
当前代码为什么阻塞本设计落地
不修改会造成什么具体问题
修改后可能影响哪些流程
如何验证这些流程没有回归
是否存在只改战斗表现层的替代方案
```

只有在确认该修改是必要且收益大于风险时，才允许进入实现。默认选择局部适配、封装或新增战斗专用入口，不把战斗渲染规则扩散到其它业务流程。

## 深度带设计

保留现有 `ROW_STEP = 100` 和普通行内公式，新增正式深度带：

```text
普通行内带：
  row * ROW_STEP + 0..99

飞行道具带：
  path_max_row * ROW_STEP + AIRBORNE_ITEM_BIAS

飞机带：
  max(row * ROW_STEP + AIRCRAFT_BIAS, map_bottom_regular_z + AIRCRAFT_MARGIN)

调试带：
  DEBUG_Z
```

建议常量：

```gdscript
const ROW_STEP := 100
const WITHIN_ROW_STEP := 10

const LAYER_PRIORITY_GROUND := 0
const LAYER_PRIORITY_FX := 1
const LAYER_PRIORITY_ACTOR := 2
const LAYER_PRIORITY_SURFACE := 3

const AIRBORNE_ITEM_BIAS := 500
const AIRCRAFT_BIAS := 1000
const AIRCRAFT_ABOVE_WORLD_MARGIN := 100
const DEBUG_Z := 10000
```

普通层级 API：

```gdscript
static func ground_z(cell: Vector2i, z_bias: int = 0) -> int
static func spawn_marker_z(cell: Vector2i, z_bias: int = 0) -> int
static func bubble_z(cell: Vector2i, z_bias: int = 0) -> int
static func explosion_segment_z(cell: Vector2i, z_bias: int = 0) -> int
static func item_ground_z(cell: Vector2i, z_bias: int = 0) -> int
static func player_z(cell: Vector2i, z_bias: int = 0, offset_y: int = 0) -> int
static func surface_z(cell: Vector2i, z_bias: int = 0) -> int
```

空中层级 API：

```gdscript
static func item_airborne_z(from_cell: Vector2i, to_cell: Vector2i, z_bias: int = 0) -> int
static func item_airborne_z_from_world(from: Vector2, to: Vector2, cell_size: float, z_bias: int = 0) -> int
static func airplane_z(row_y: int, map_height: int = 0, z_bias: int = 0) -> int
static func debug_z(z_bias: int = 0) -> int
```

`item_airborne_z_from_world()` 应等价承接当前实现：

```gdscript
max_row = max(floor(from.y / cell_size), floor(to.y / cell_size))
z = max_row * ROW_STEP + AIRBORNE_ITEM_BIAS + z_bias
```

`airplane_z()` 应兼容当前视觉意图，同时对地图高度更稳健：

```gdscript
row_based = row_y * ROW_STEP + AIRCRAFT_BIAS + z_bias
if map_height > 0:
  bottom_regular = (map_height - 1) * ROW_STEP + LAYER_PRIORITY_SURFACE * WITHIN_ROW_STEP
  return max(row_based, bottom_regular + AIRCRAFT_ABOVE_WORLD_MARGIN + z_bias)
return row_based
```

这样飞机在所有正式地图上稳定高于世界对象，且不会被未来更高行数地图意外压住。

## 对象深度契约

地面：

```text
floor tile、spawn marker 使用 ground/spawn marker z。
地面不参与遮挡玩家。
```

surface：

```text
普通墙体、箱子、立面装饰使用 surface_z(anchor_cell, z_bias)。
多格 surface 额外建立 occupied cell 到 render z 的缓存，用于遮挡查询。
```

玩家：

```text
基础 z = player_z(cell, 0, offset_y)
offset_y 参与 z，保证半格移动时深度平滑变化。
如果局部 surface 或 channel 遮挡要求玩家显示在其上方，则 z = max(z, occluder_z + 1)。
玩家内部：
  team marker: relative -10
  body: relative 0
  status effect: relative +10
```

泡泡：

```text
基础 z = bubble_z(cell)
如果 cell 是 channel cell，当前行为是隐藏。
后续应由 ChannelVisualPolicy 决定 hidden/alpha/mask，而不是在 BubbleActorView 写死。
```

爆炸：

```text
每个 segment 应使用自己的 explosion_segment_z(cell)。
不建议整个 BattleExplosionActorView 只用中心 cell z。
如果继续用一个父节点承载全部 segment，则父节点只负责生命周期，segment 子节点负责自身深度。
```

普通道具：

```text
落地道具 z = item_ground_z(cell)
拾取延迟不影响 z
```

飞行中掉落物：

```text
飞行中 z = item_airborne_z_from_world(scatter_from_world, target_world, cell_size)
飞行中不被每 tick apply_view_state 的落地 z 覆盖。
落地后 z = item_ground_z(target_cell)
```

飞机：

```text
z = airplane_z(airplane_y, map_height)
飞机挂在 ActorLayer 可以保留，但深度必须由 BattleDepth 统一计算。
飞机应高于飞行中掉落物。
```

临时 FX：

```text
砖块破碎：high local fx 或 surface break fx，取 destroyed cell。
拾取光效：high local fx，取 pickup cell。
预测修正：debug/world marker，取修正路径最大行或 debug_z。
```

## 通道设计

通道应拆成三个明确语义：

```text
movement_pass_mask
  仿真移动使用，决定 from/to 方向是否可跨格。

allow_place_bubble
  泡泡放置使用，决定通道格能否放泡泡。

visual_occlusion
  表现使用，决定玩家/泡泡/特效在通道中是否隐藏、半透明、抬高或压低。
```

当前数据只有 `movement_pass_mask` 与 `allow_place_bubble`，表现层用 channel cell 是否存在来推导 `visual_occlusion`。短期可以保留，长期建议在 `channel_entries` 中补充可选表现字段：

```text
visual_policy = hide_actor_body | alpha_actor_body | none
hide_bubble = true | false
occlusion_z_mode = surface_render | none
```

玩家通道表现应保持当前优点：

```text
用碰撞中心判断是否进入 channel。
使用半格距离判断隐藏，避免只按 cell 导致跳变。
跨连接边时保持隐藏，避免边界闪烁。
```

通道与掉落物的关系：

```text
空投落点当前要求 GridState tile_type == EMPTY。
如果通道是从 surface/solid 中挖出的方向通路，tile_type 仍可能不是 EMPTY，因此不会成为空投落点。
这符合直觉：飞机不应把道具丢进被覆盖的通道内部。
如果未来需要允许通道掉落，必须新增 allow_air_drop 或 drop_policy，而不是复用 movement_pass_mask。
```

通道与泡泡的关系：

```text
allow_place_bubble 决定能否放泡泡。
BubbleActorView 当前在 channel cell 隐藏泡泡。
如果 allow_place_bubble=true 且 hide_bubble=true，仿真上泡泡存在，表现上被通道覆盖。
这要求 debug 模式能显示 hidden bubble，否则排查会困难。
```

## Surface 局部遮挡缓存

当前 `BattleMapViewController` 维护：

```text
_surface_virtual_z_by_cell
_surface_row_max_z
_surface_render_z_by_cell
```

其中 `_surface_row_max_z` 会导致同一行所有玩家都可能被抬高，安全但粗糙。建议改为局部遮挡缓存：

```gdscript
surface_occlusion_by_cell[cell] = {
  "instance_id": String,
  "anchor_cell": Vector2i,
  "occupied_cell": Vector2i,
  "surface_z": int,
  "render_z": int,
  "render_role": String,
  "interaction_kind": String,
  "z_bias": int,
}
```

玩家每 tick 只查询候选格：

```text
当前 foot cell
碰撞中心所在 cell
左右上下邻格
channel candidate cells
```

查询规则：

```text
如果 candidate cell 有 surface occlusion，玩家 z 至少为 render_z + 1。
如果玩家不在 surface footprint 或 channel 覆盖范围内，不做整行抬高。
如果多个 surface 覆盖，取最高 render_z。
```

迁移阶段可以保留 `_surface_row_max_z` 作为 fallback，并在 debug 中显示：

```text
depth_reason = surface_local | surface_row_fallback | channel | base
```

## 组件改造方案

第一阶段：收束魔法 z

```text
修改 BattleDepth：
  增加 airborne item、airplane、debug API。

修改 AirplaneActorView：
  不再手写 row_y * 100 + 1000。
  通过 BattleDepth.airplane_z(row_y, map_height) 计算。

修改 ItemActorView：
  不再手写 max_row * 100 + 500。
  通过 BattleDepth.item_airborne_z_from_world(from, to, cell_size) 计算。
```

第二阶段：FX 全量入深度系统

```text
ExplosionActorView：
  父节点不再只用 center cell z 决定全部 segment。
  segment 节点逐个按 cell 计算 z。

BrickBreakFxPlayer：
  configure 增加 cell 或 z 参数。

ItemPickupFxPlayer：
  configure 增加 cell 或 z 参数。

CorrectionMarkerView：
  configure 增加 z 策略，默认 debug_z。
```

第三阶段：局部 surface 遮挡

```text
BattleMapViewController：
  构建 surface_occlusion_by_cell。
  暴露 get_surface_occlusion_by_cell()。

ActorRegistry：
  将 surface_occlusion_by_cell 传入 PlayerActorView。

PlayerActorView：
  用局部候选 cell 替代整行 _surface_row_max_z。
  保留旧字段 fallback 一版。
```

第四阶段：通道表现策略

```text
新增 ChannelVisualPolicy 或在 PlayerActorView/BubbleActorView 中抽出静态策略函数。
输入 channel_pass_mask_by_cell、surface_occlusion_by_cell、view_state。
输出 hide_body_sprite、hide_bubble、z_override_reason。
```

第五阶段：调试与测试

```text
z debug label 显示：
  entity id
  cell
  base z
  final z
  reason
  channel mask
  surface instance id

新增或扩展测试：
  飞机 z 高于地图世界对象
  飞行中掉落物 z 高于路径附近 surface
  掉落物落地恢复 item_ground_z
  channel 双向 pass mask 生效
  channel 中泡泡隐藏但仿真实体存在
  玩家跨 channel 连接边不闪烁
  surface 局部遮挡不会抬高同一行远处玩家
```

## 风险与边界

视觉回归风险：

```text
整行 surface 抬高玩家虽然粗糙，但可能掩盖素材 footprint 或 anchor 配错。
切到局部遮挡后，错误数据会暴露为穿帮。
必须先加 debug，再切行为。
```

节点数量风险：

```text
爆炸 segment 拆独立 z 后，节点或 CanvasItem 数量会增加。
QQTang 地图规模较小，短期可接受。
如果后续爆炸密度升高，可用对象池或按行分组优化。
```

快照一致性风险：

```text
ItemPoolRuntime 当前进入标准快照，但 light snapshot 不包含 item_pool_runtime。
如果 rollback 或客户端预测路径需要重放飞机投送，应确认使用的快照类型是否包含 item_pool_runtime。
飞机状态属于仿真权威状态，不应只存在表现层。
```

通道语义混用风险：

```text
movement_pass_mask 不等于 visual occlusion。
allow_place_bubble 不等于 allow_air_drop。
未来新增通道掉落或通道特效时，应新增字段，不要复用现有字段做隐式推导。
```

HUD 层风险：

```text
当前 WorldRoot 会压过 CanvasLayer。
飞机和 debug 深度提高后，仍只应影响 WorldRoot 内部排序。
不得用 CanvasLayer 逃避世界深度问题，否则会破坏相机缩放和地图对齐。
```

## 验证计划

修改 GDScript 前必须先跑语法预检：

```powershell
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
```

涉及内容数据或地图资源时再跑：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1
```

建议覆盖的自动化测试：

```text
tests/unit/battle/map_surface_element_view_test.gd
tests/integration/battle/presentation_sync_test.gd
tests/contracts/content/map_resource_generation_contract_test.gd
tests/contracts/content/map_tile_direction_pass_contract_test.gd
```

建议新增测试：

```text
tests/unit/battle/battle_depth_contract_test.gd
tests/unit/battle/item_airborne_depth_test.gd
tests/unit/battle/channel_visual_policy_test.gd
tests/integration/battle/airplane_drop_presentation_test.gd
```

人工验证场景：

```text
飞机从右向左飞过地图，飞机始终高于地图、角色、surface。
飞机投送道具时，道具飞行轨迹高于路径附近 surface，落地后回到地面层级。
玩家进入纵向通道，身体隐藏；离开通道后恢复。
玩家沿连接通道边缘移动，隐藏状态不闪烁。
泡泡放在通道中，仿真存在但表现不穿出通道覆盖物。
同一行远处有高 surface 时，玩家不应无条件被抬到 surface 之上。
```

## 结论

当前项目的方向是正确的：用绝对 `z_index` 建立确定性战斗深度，而不是依赖节点顺序或 `YSort`。飞机投送和通道处理不是反例，而是说明需要把“空中深度带”和“通道表现策略”正式纳入架构。

推荐先做小步收束：把飞机与飞行掉落物的魔法 z 值移动到 `BattleDepth`，再逐步统一 FX 和 surface 局部遮挡。这样改动风险可控，同时能为后续复杂地图、更多道具、更多技能特效建立稳定扩展点。
