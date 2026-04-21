# network

## 目录定位
正式联机实现主目录。

## 子目录职责
- `runtime/`：联机运行期入口与客户端/战斗相关运行时实现（含正式 Battle DS bootstrap）。
- `session/`：正式会话域模型与共享能力（Room authority 的正式实现不在 Godot legacy 路径，而在 `services/room_service`）。
- `transport/`：网络传输抽象、协议调试与传输侧支撑能力。

## 维护规则
- 新增正式联机逻辑优先进入本层。
- legacy/compat 路径已物理删除，不得回流：
  - `gameplay/network/session/`
  - `network/runtime/legacy/`
  - `network/session/legacy/`
  - `network/runtime/dedicated_server_bootstrap.gd`
  - `network/session/runtime/server_room_runtime.gd`
  - `network/session/runtime/server_room_runtime_compat_impl.gd`
  - `network/session/runtime/legacy_room_runtime_bridge.gd`
- 新逻辑必须写入正式路径（如 `network/session/runtime/*`、`network/runtime/battle_dedicated_server_bootstrap.gd`）。
- 任何新逻辑不得写回已删除的 legacy/compat 路径。
