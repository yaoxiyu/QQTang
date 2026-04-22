# Battle Handoff Projection Repair Plan

## Purpose
记录 2026-04-22 双客户端实测中出现的 battle 过程中 Room 状态回流问题，说明前因后果、当前短期保护、为什么它不满足 Phase28 目标态，以及后续正确落地路径。

这份文档用于交接给后续会话：新会话应优先修服务端 `room_service` 状态机投影，而不是继续在客户端叠加 guard。

## Phase28 Design Context
Phase28 的状态机设计原则来自：

`F:\Obsidian\02-项目\QQ堂重置\31_Phase28_状态机收敛工程化方案\02_Phase28_详细工程化系统设计.md`

关键约束：

- Room / Queue / Battle 真相来自服务端投影。
- Front FSM 只做场景编排消费，不解释服务端业务真相。
- Battle Handoff 是独立子状态机，不能退化成 `battle_entry_ready bool` 或模糊字符串。
- 兼容旧字段可以存在，但旧字段必须是 canonical phase 的派生视图。
- 状态迁移必须由 command + guard 驱动，不能由客户端根据本地状态猜测并修正服务端状态。

## Observed Problem
在 `logs/clients_dev_20260422_135850/` 与 `logs/battle_ds/battle_a58a21f3cb20c3e1.log` 中，battle 确实成功进入，但 Room Session 状态被 stale room snapshot 降回房间。

关键时间线：

- `13:59:40`
  - 客户端收到 room snapshot，进入 `MATCH_LOADING`。
  - battle entry context 指向 `battle_a58a21f3cb20c3e1` / `127.0.0.1:19010`。

- `13:59:52`
  - 客户端本地 `mark_match_started`：
  - `session.room_flow_state MATCH_LOADING -> IN_BATTLE`
  - `session.lifecycle_state MATCH_LOADING -> MATCH_ACTIVE`

- `13:59:57`
  - 两个客户端成功连接 Battle DS：
  - client1: `connected_to_server local=2135434897`
  - client2: `connected_to_server local=1088631836`
  - DS 收到两个 `BATTLE_ENTRY_REQUEST`，发送 `BATTLE_ENTRY_ACCEPTED` / `JOIN_BATTLE_ACCEPTED` / `MATCH_START` / `CHECKPOINT`。

- `13:59:58`
  - 客户端释放权威开局：
  - `dedicated_authority_opening_released`

- `13:59:57` 与 `14:00:26`
  - 两个客户端出现：
  - `session.room_flow_state IN_BATTLE -> IN_ROOM (authoritative_snapshot)`
  - `session.lifecycle_state MATCH_ACTIVE -> ROOM_ACTIVE (authoritative_snapshot)`

- `14:01:03` 与 `14:01:24`
  - DS 记录 peer disconnect。
  - 这两个断开是手动关闭客户端导致，不是本问题根因。

结论：Battle DS 连接与权威 tick 没有失败。问题是 room authoritative snapshot 在 battle active 期间仍投影了 `room_phase=idle` 或空 phase，客户端 `RoomSessionController.apply_authoritative_snapshot()` 将其映射成 `IN_ROOM/ROOM_ACTIVE`。

## Why The Current Client Fix Is Not The Final Architecture
当前已有短期保护：

- `app/front/room/room_phase_to_front_flow_adapter.gd`
  - 在 FrontFlow 已处于 `MATCH_LOADING` / `BATTLE` / `SETTLEMENT` 时，忽略 `idle` room phase，避免直接切回 room 场景。

- `network/session/room_session_controller.gd`
  - 在本地已处于 `IN_BATTLE/MATCH_ACTIVE` 时，遇到 `room_phase=idle` 或空 phase 且 battle 未完成，保留本地 active battle 状态。

- `app/front/room/room_use_case.gd`
  - `current_room_snapshot` 改为使用 `room_session_controller.build_room_snapshot()`，避免其他 UI 读到未经规整的 stale snapshot。

这些修复有测试保护，但不是 Phase28 目标态：

- 它让客户端根据本地状态判断服务端 snapshot 是否 stale，违反“前端只消费服务端投影”。
- 它把 Room FSM 与 Battle Handoff FSM 的跨域解释放到了客户端。
- 后续接入 reconnect、settlement、观战、掉线保活后，guard 条件会膨胀。
- 它只能防止 UI 被拉回，不能保证服务端投影语义正确。

因此它应被视为兼容期安全网，不应继续扩展成长期方案。

## Correct Target Behavior
服务端 `room_service` 应保证：

- 一旦 battle handoff 进入 active，room snapshot 必须持续投影：
  - `room_phase=in_battle`
  - `battle_phase=active`
  - `match_active=true`
  - room capability 禁用不可用操作，例如 enter queue、toggle ready、update selection。

- 只有明确命令才能离开 battle：
  - battle finished
  - returning to room
  - return completed
  - room closed / destroyed

- 普通 room snapshot 同步、队列状态刷新、legacy lifecycle alias 派生，不得把 active battle 房间写回 `idle`。

## Suspected Source Area
优先检查以下文件：

- `services/room_service/internal/roomapp/room_transition_engine.go`
  - 是否存在 canonical `RoomState.Phase` 的 command/guard 迁移。
  - 是否有某些 command 在 battle active 后仍将 phase 写为 `idle`。

- `services/room_service/internal/roomapp/service.go`
  - 匹配队列状态同步、assignment handoff、battle allocation ready、battle entry ack、return room 等入口。
  - 是否只更新 legacy `LifecycleState`，没有稳定设置 canonical room phase。

- `services/room_service/internal/roomapp/state_alias_mapper.go`
  - legacy lifecycle 是否是 canonical phase 的派生结果。
  - 禁止 legacy field 反向覆盖 canonical phase。

- `services/room_service/internal/roomapp/capability_projection.go`
  - battle active 下 capabilities 是否统一关闭。

- `services/room_service/internal/wsapi/encoder.go`
  - snapshot 是否把 canonical phase / battle phase / capability 正确输出。

## Implementation Plan

### 1. Reproduce From Logs
先用现有日志确认服务端投影问题：

```powershell
Select-String -Path logs\clients_dev_20260422_135850\client*.godot.log -Pattern "authoritative_room_snapshot_received|IN_BATTLE -> IN_ROOM|MATCH_ACTIVE -> ROOM_ACTIVE|battle_entry_context_built|dedicated_authority_opening_released"
Select-String -Path logs\battle_ds\battle_a58a21f3cb20c3e1.log -Pattern "battle_ds started|peer_connected|BATTLE_ENTRY_REQUEST|MATCH_START|CHECKPOINT|peer_disconnected"
```

预期：客户端已经进入 battle 并成功收首帧权威数据，但后续 room snapshot 把 session 状态降为 room。

### 2. Add Server-Side Failing Tests First
在 `services/room_service/internal/roomapp/` 添加或扩展测试，覆盖：

- battle allocation ready 后，room phase 不应回 idle。
- battle entry acknowledged 后，room phase 应为 `in_battle` 或可明确进入 `in_battle` 的 handoff phase。
- battle active 期间重复队列/房间状态同步不会把 phase 降为 `idle`。
- 只有 return completed / battle finalized return 命令能回 `idle`。
- battle active 时 capability：
  - `can_enter_queue=false`
  - `can_cancel_queue=false`
  - `can_toggle_ready=false`
  - `can_update_selection=false`
  - `can_update_match_room_config=false`

候选测试文件：

- `services/room_service/internal/roomapp/sync_match_queue_status_test.go`
- `services/room_service/internal/roomapp/ack_battle_entry_test.go`
- 新增 `battle_handoff_projection_test.go`

### 3. Fix Canonical Phase Transitions
在 `room_transition_engine.go` 中确保 battle handoff 相关 command 的 canonical phase 单调流转：

```text
idle / queue_active
  -> battle_allocating
  -> battle_entry_ready
  -> battle_entering
  -> in_battle
  -> returning_to_room
  -> idle
```

注意：

- terminal reason 放到 reason 字段，不要用 terminal 字符串替代 phase。
- 不允许业务 handler 直接写 `RoomState.Phase = "idle"` 来表示“当前命令处理完了”。
- 如果当前缺少 command 名称，应新增明确命令，而不是直接写字段。

### 4. Fix Battle Handoff Projection
在 `service.go` 中找到 assignment / queue / battle allocation / battle entry ack 流程：

- battle DS ready 后投影 `battle_phase=ready`。
- client entry ack 或 DS match start 后投影 `battle_phase=active` 与 `room_phase=in_battle`。
- battle active 期间，任何旧 queue sync 都不得覆盖 room phase。

如果当前 game_service 不能明确通知 `in_battle`，room_service 至少应在 battle entry acknowledged 后进入 `in_battle`，并等待 finalize/return 命令退出。

### 5. Add Revision Or Epoch Guard
长期建议在 room snapshot 中加入 phase 版本字段：

- `room_phase_revision`
- 或统一 `snapshot_revision`
- 或 `handoff_revision`

客户端只接受 revision 单调递增的 snapshot。这样可以从协议层解决乱序 stale snapshot，而不是由客户端本地状态猜测。

如果本轮改动不引入协议字段，至少应保证 room_service 内部 phase 迁移单调，并在投影层不生成 active battle 的 idle snapshot。

### 6. Downgrade Client Guard
服务端修好后，客户端应回归纯消费：

- `RoomSessionController.apply_authoritative_snapshot()` 只复制服务端 snapshot 并映射 canonical phase。
- 删除或保留最小兼容 `_should_preserve_active_battle_for_snapshot()`，但不要继续扩展其业务条件。
- `RoomPhaseToFrontFlowAdapter` 继续只负责 scene flow 编排。

理想最终状态：

- 客户端通过 `room_phase=in_battle` 保持 battle。
- 通过 `room_phase=returning_to_room` 进入 returning。
- 通过 `room_phase=idle` 且 battle completed/return completed 后回 room。

## Current Short-Term Changes To Be Aware Of
截至 2026-04-22，本地工作树包含以下相关短期保护：

- `app/front/room/room_phase_to_front_flow_adapter.gd`
  - FrontFlow battle 中忽略 stale idle。

- `network/session/room_session_controller.gd`
  - `_should_preserve_active_battle_for_snapshot()` 保护 active battle 不被 stale idle 降级。

- `app/front/room/room_use_case.gd`
  - `current_room_snapshot` 使用 controller 规整后的 snapshot。

- `tests/unit/network/match_room_kind_state_test.gd`
  - 覆盖 active battle 不被 idle snapshot 降级，return completed 后可以回 room。

这些保护不应作为继续扩展的设计基础。服务端投影修复完成后，应评估删除或收窄它们。

## Validation Checklist
完成服务端修复后，至少运行：

```powershell
go test ./services/room_service/internal/roomapp/...
go test ./services/room_service/internal/wsapi/...
powershell -ExecutionPolicy Bypass -File tests\scripts\run_gut_suite.ps1 -GodotExe D:\Godot\Godot.exe -ProjectPath . -SuiteName targeted_match_room_kind_state -TestFiles @('res://tests/unit/network/match_room_kind_state_test.gd')
powershell -ExecutionPolicy Bypass -File tests\scripts\run_gut_suite.ps1 -GodotExe D:\Godot\Godot.exe -ProjectPath . -SuiteName targeted_room_to_loading_to_battle_flow -TestFiles @('res://tests/integration/front/room_to_loading_to_battle_flow_test.gd')
D:\Godot\Godot.exe --headless --path . --quit
```

人工双客户端验证：

- 匹配进入 battle 后，room UI 不应叠在 battle 上。
- 客户端日志不应出现 battle active 期间：
  - `session.room_flow_state IN_BATTLE -> IN_ROOM (authoritative_snapshot)`
  - `session.lifecycle_state MATCH_ACTIVE -> ROOM_ACTIVE (authoritative_snapshot)`
- DS 日志应持续向两个 peer 广播，直到玩家主动关闭或 battle 正常结束。

## Done Definition
这项工作完成的标准：

- 服务端不会在 battle active 期间投影 `room_phase=idle`。
- 客户端不需要依赖本地 active battle 状态修正服务端 snapshot。
- Room / Queue / Battle Handoff 状态域职责清晰：
  - Queue FSM 不决定 room UI。
  - Battle Handoff FSM 不退化为 legacy bool/string。
  - Front FSM 不解释服务端真相，只消费 projection。
- 新增服务端状态机测试覆盖 stale projection 回归。
- 双客户端实测中 battle 过程没有 room 界面叠加。
