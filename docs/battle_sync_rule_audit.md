# Battle Sync Rule Audit

> 目标：从全局同步设计角度重新定义 battle 各状态域的真相归属、消息职责、预测边界与当前实现偏差。  
> 适用范围：`dedicated_server` 拓扑下的客户端预测、`STATE_SUMMARY` sideband 恢复、`CHECKPOINT` 回滚校验。  
> 结论优先：当前最危险的问题不是单个字段漏同步，而是 **`STATE_SUMMARY` 正在修改历史 `snapshot_buffer`，而 `CHECKPOINT` 又只校验历史快照，不直接校验当前活跃预测世界**。这会掩盖真实分叉。

## 1. 设计目标

Battle 同步要同时满足 4 件事：

1. 本地手感即时。
2. 服务端规则绝对权威。
3. 历史快照可回滚、可重演、可验证。
4. summary 只能加速恢复显示，不能破坏 rollback 证据链。

如果一个机制让 1 更好，但破坏了 2/3，就会出现“本地看起来顺，服务器其实已经判你在别处”的严重问题。

## 2. 状态域分层

### 2.1 A 层：本地立即预测，允许 rollback 重演

这些状态直接决定本地手感，必须立即进入预测世界：

- 本地受控玩家移动输入
- 本地受控玩家位置：
  - `cell_x/cell_y`
  - `offset_x/offset_y`
  - `facing`
  - `move_state`
  - `move_phase_ticks`
  - `last_non_zero_move_x/y`
- 本地放泡输入边沿：
  - `last_place_bubble_pressed`
- 本地放泡命令结果中的资源消耗：
  - `bomb_available` 在“本地预测判定本次放泡成功”时必须同步扣减

规则：

- 必须先在本地预测世界执行。
- 若与权威不一致，只能通过 rollback / 当前世界修正收敛。
- 不能只改历史快照、不改当前活世界。
- dedicated server 拓扑下也不能关闭本地 `action_place` 预测；服务端权威的是最终结果，不是“是否允许先预测放泡命令本身”。

### 2.2 B 层：权威 sideband，可恢复到当前世界

这些状态是强权威结果，但可以通过 summary 提前恢复到当前预测世界，让表现层尽快看到：

- `bubbles`
- `items`
- authority `events`
- `walls`

规则：

- summary 可以把这些状态恢复到 **当前预测世界**。
- `walls` 这类持久地图状态应由权威 sideband 恢复到当前世界，而不是由单个事件直接驱动地图真相。
- summary 不应篡改历史 rollback 证据。
- 如果要参与 checkpoint 校验，历史快照必须来自“当时真实预测结果”或“明确的当前世界对齐重建”，不能靠事后涂改。

### 2.3 C 层：只允许 checkpoint 作为最终裁决

这些内容属于历史一致性真相：

- 历史 tick 的玩家/泡泡/道具快照
- rollback 起点
- replay 结果
- checksum 对应的状态面

规则：

- 只能由当时的预测执行自然生成，或由完整权威 snapshot 恢复。
- 不能被 `STATE_SUMMARY` 事后补丁“美化”。

### 2.4 D 层：远端玩家仅权威驱动

- 非本地受控玩家的位置与移动态

规则：

- 客户端不预测远端移动。
- summary / checkpoint 可直接刷新远端玩家状态。

## 3. 消息职责

### 3.1 `STATE_SUMMARY`

应该承担的职责：

- 提供轻量级权威 sideband：
  - `player_summary`
  - `bubbles`
  - `items`
  - `events`
  - `checksum`
- 更新当前预测世界中“允许被 sideband 修正”的部分。
- 缩短表现层落后感。

不应该承担的职责：

- 修改历史 rollback 快照的证据链。
- 代替 checkpoint 做最终一致性裁决。
- 让 rollback 因为历史快照被补平而不再触发。

### 3.2 `CHECKPOINT`

应该承担的职责：

- 提供完整裁决面：
  - `players`
  - `bubbles`
  - `items`
  - `walls`
  - `mode_state`
  - `rng_state`
  - `checksum`
- 与历史预测快照比较，决定：
  - 无需处理
  - rollback
  - full resync

## 4. 各状态字段规则表

| 状态域 | 字段/对象 | 是否预测 | 是否允许 summary 修正 | 最终裁决 |
|---|---|---:|---:|---:|
| 本地玩家移动 | `cell_x/cell_y`, `offset_x/y`, `move_state`, `move_phase_ticks`, `facing` | 是 | 仅允许修正当前世界 | checkpoint |
| 本地放泡输入边沿 | `last_place_bubble_pressed` | 是 | 不允许 summary 覆盖当前边沿态 | dedicated_server 下不进入历史 rollback 强比较 |
| 本地放泡资源态 | `bomb_available` | 是 | 可修正当前世界 | dedicated_server 下以当前世界权威修正为主，不进入历史 rollback 强比较 |
| 本地资源态 | `bomb_capacity`, `bomb_range`, `speed_level` | 是 | 可修正当前世界 | checkpoint |
| 远端玩家移动 | 同上 | 否 | 可直接修正 | summary/checkpoint |
| 泡泡集合 | `bubbles` | listen/单机下可随预测世界自然产生；dedicated_server 下不预测实体结果 | 可修正当前世界 | listen/单机下由 checkpoint；dedicated_server 下不进入历史 rollback 强比较，由当前世界权威修正收敛 |
| 泡泡通行名单 | `ignore_player_ids` | 否 | 可修正当前世界 | checkpoint |
| 道具集合 | `items` | listen/单机下随预测世界自然演进；dedicated_server 下不作为本地历史预测真相 | 可修正当前世界 | listen/单机下由 checkpoint；dedicated_server 下不进入历史 rollback 强比较，由当前世界权威修正收敛 |
| 地图/模式 | `walls` | 否 | 可由权威 sideband 修正当前世界；历史快照不允许被 summary 回填 | checkpoint |
| 地图/模式 | `mode_state` | 否 | 否 | checkpoint |
| 历史快照 | `snapshot_buffer[tick]` | 由预测自然生成 | 否 | checkpoint |

## 5. 当前实现对照

### 5.1 基本合理的部分

1. 服务端每 tick 输出 `STATE_SUMMARY`，每 5 tick 输出 `CHECKPOINT`。  
   见 `res://network/session/runtime/server_session.gd`。

2. 远端玩家在客户端预测模式下不再走本地移动系统。  
   见 `res://gameplay/simulation/systems/movement_system.gd` 中 `_should_preserve_authoritative_remote_state()`。

3. `BubblePlacementSystem` 与 `BubblePlaceResolver` 已统一放泡格解析。  
   这保证了客户端门控与服务端规则至少在“目标格定义”上可共用。

### 5.2 当前最危险的结构偏差

#### 偏差 1：`STATE_SUMMARY` 正在修改历史 `snapshot_buffer`

位置：

- `res://network/session/runtime/client_runtime.gd`
- `_refresh_snapshot_buffer_from_authoritative_summary()`
- `_patch_snapshot_players_from_summary()`

现状：

- 会对历史 snapshot 直接覆盖：
  - `players`
  - `bubbles`
  - `items`
  - `checksum`

风险：

- `RollbackController.on_authoritative_snapshot()` 比较的是 `snapshot_buffer.get_snapshot(tick)`。
- 一旦 summary 提前把历史快照补平，checkpoint 就可能误判“一致”。
- 但当前活着的预测世界并没有被同样修正，结果就是：
  - 本地位置继续漂
  - 放泡判定用错位置
  - 服务端爆炸命中与本地认知脱节

这正符合“长时间不能放泡、最后莫名炸死自己”的症状。

#### 偏差 2：当前世界修正与历史快照修正被混在一起

现状：

- `STATE_SUMMARY` 同时做了两件不同层级的事：
  - 修当前预测世界
  - 修历史 snapshot

风险：

- 当前世界修正是“为了手感收敛”。
- 历史快照修正是“修改 rollback 证据”。
- 这两件事不能共用一套逻辑，更不能默认同步执行。

#### 偏差 3：`last_place_bubble_pressed` 被当成历史补丁字段

现状：

- `player_summary` 中携带 `last_place_bubble_pressed`
- summary 还会回写到历史 player snapshot

风险：

- 这个字段是输入边沿辅助态。
- 如果历史上被事后改写，可能导致：
  - 本地输入门控状态与真实 replay 链不一致
  - rollback 被隐藏
  - “本地以为已经松键 / 服务器仍认为处于放泡边沿” 的错位难以定位

#### 偏差 4：`ignore_player_ids` 属于强权威状态，但目前被 summary 历史回填掩盖分叉

现状：

- `ignore_player_ids` 来源于泡泡生成瞬间的重叠关系和后续移动退出逻辑。
- 它直接影响玩家能否穿过自己刚放的泡泡。

风险：

- 这个状态一旦与位置漂移叠加，就会让“本地还能走 / 服务端已卡住”或者反过来。
- 这是放泡后被卡、被炸、自以为在安全格但服务端判在爆炸格的高危根因之一。

#### 偏差 5：道具也存在同样的历史补丁污染问题

现状：

- `items` 通过 summary 回填到 snapshot。

风险：

- 道具是强权威对象。
- 如果历史快照被回填，而当前活世界没有严格同源修正，就会出现：
  - 本地以为吃到了 / 没吃到
  - `speed_level`、`bomb_capacity`、`bomb_range` 连锁漂移

#### 偏差 6：dedicated server 下不能直接把 `action_place` 映射为完整世界预测

现状：

- dedicated server 客户端如果直接让 `prediction_frame.action_place = true`
- 就会在预测世界里执行完整 `BubblePlacementSystem`
- 从而本地产生：
  - 预测泡泡实体
  - 预测爆炸链
  - 预测 authority-only sideband 变化

风险：

- 客户端会同时看到：
  - 预测泡泡 / 预测爆炸
  - 权威 summary / checkpoint 恢复出来的泡泡 / 爆炸
- 这会直接表现为：
  - 泡泡闪烁
  - 爆炸闪烁
  - 大幅拉回 / 突然回原点

因此 dedicated server 下正确做法不是“完整开启 place 世界预测”，而是：

- **禁止 authority-only 实体预测**
  - 泡泡实体
  - 爆炸效果
  - 道具 sideband
- **允许独立的 place pending / 输入边沿本地态**
  - 仅用于 UI / 门控 / 短期一致性判断
  - 不直接驱动预测世界生成泡泡实体

## 6. 对用户现象的解释

### 6.1 十几秒不能放泡泡

高概率链路：

1. 本地活世界位置已经漂移。
2. rollback 因为历史 snapshot 被 summary 事后补平，没有及时发生。
3. 本地 `BubblePlaceResolver` 仍按漂移位置算目标格。
4. 服务端按真实位置/泡泡阻挡/`ignore_player_ids` 判定，拒绝放泡。
5. 本地只看到“输入有了，但长期不成功”。

### 6.2 放完泡泡无缘无故炸死自己

高概率链路：

1. 本地预测位置与服务端权威位置不同。
2. 泡泡、穿透名单、爆炸命中都在服务端按真实位置结算。
3. 客户端因为 rollback 被掩盖，没有及时回正。
4. 最终表现成“我这边明明不该死，但服务器判死了”。

## 7. 收敛原则

### 7.1 必须立刻遵守的原则

1. `STATE_SUMMARY` 不再修改历史 `snapshot_buffer` 的 rollback 证据。
2. `STATE_SUMMARY` 只修当前预测世界中允许修正的 sideband 状态。
3. 本地受控玩家的位置类状态，若要修，只能修当前世界，不可只修历史快照。
4. `CHECKPOINT` 必须继续对“真实历史预测结果”做比较。

### 7.2 修复顺序

#### 第一优先级：解除历史快照污染

- 停止 `STATE_SUMMARY` 对 `snapshot_buffer[tick]` 的直接覆盖：
  - 尤其是 `players`
  - `bubbles`
  - `items`
  - `checksum`

这是当前最关键的止血点。

#### 第二优先级：把 summary 修正限定到“当前世界”

- 本地受控玩家：
  - 资源态可 current-world 修正
  - 位置态要谨慎，只能在 tick 对齐条件下修当前世界
- 远端玩家：
  - 可继续直接以权威驱动
- `bubbles/items/events`：
  - 只恢复到当前世界，不写历史证据
  - 只能按权威 sideband 的单调前沿恢复；不能把更旧 tick 的权威实体集合整包覆盖到已经应用过更新 sideband 的当前预测世界
  - dedicated_server 下是否应用 sideband，判断基准必须是“是否比上次已应用的权威 sideband 更新”，不能直接拿预测世界 tick 当门限
  - `walls` 由权威 sideband 恢复到当前世界；`CELL_DESTROYED` 事件只负责瞬时表现，不直接承担持久地图真相同步

#### 第三优先级：把 `ignore_player_ids` 明确列为 checkpoint 强校验项

- 它不是装饰字段，是碰撞/通行规则的一部分。
- 任何 `ignore_player_ids` 漂移都必须能触发 rollback。

#### 第四优先级：把 `last_place_bubble_pressed` 从“历史补丁字段”降级为“当前输入态”

- 它可以参与 checkpoint。
- 但不应该再通过 summary 去美化历史。
- 在 `dedicated_server` 拓扑下，它不应该再作为历史 rollback 强比较字段，否则只会反复放大 place 边沿时序差异。

#### 第五优先级：为 dedicated server 单独设计 place pending 通道

- 不在预测世界里直接生成 dedicated server 的本地泡泡。
- 单独维护 place pending / 资源占用预期态。
- 服务端仍然保留最终裁决：
  - 泡泡是否合法
  - `ignore_player_ids`
  - 泡泡生命周期
  - 爆炸结果

在 place pending 机制真正落地之前，当前收敛规则应为：

- `STATE_SUMMARY` 不改历史 snapshot；
- `dedicated_server` 下历史 rollback 对比忽略：
  - `last_place_bubble_pressed`
  - `bomb_available`
- 当前世界仍允许被 summary 的本地资源态修正覆盖，以保持门控/UI 尽快收敛。

## 8. 当前建议的执行方案

### 方案 A：先止血，再细化

1. 去掉 `STATE_SUMMARY -> snapshot_buffer` 的历史写入。
2. 保留 `STATE_SUMMARY -> 当前预测世界` 的 sideband 恢复。
3. 重新观察：
   - rollback 次数是否上升
   - “无法放泡/自杀”是否明显下降

优点：

- 最快验证核心结构猜想。
- 风险最低。

代价：

- rollback 可能短期变多，但这是把真实问题重新暴露出来，不是退化。

### 方案 B：再做精细字段分层

在 A 之后，把字段按以下策略落细：

- `current_only_summary_fields`
- `checkpoint_only_fields`
- `remote_authoritative_fields`
- `predicted_local_fields`

避免后续再混用。

## 9. 最终判断

当前 battle 同步问题的本质，不是“某几个字段没同步”，而是 **同步层级被混了**：

- summary 本该是当前世界 sideband 恢复工具，
- 却被拿来修改 rollback 历史证据，
- 结果让系统失去了及时纠正本地活世界漂移的能力。

在这个结构没有纠正之前，继续补 `bomb_available`、`items`、`ignore_player_ids`、`last_place_bubble_pressed` 只会越补越乱。
