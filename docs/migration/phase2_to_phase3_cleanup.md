# Phase2 To Phase3 Cleanup

## Retired Paths

以下 Phase2 sandbox 路径已经退役：
- `res://scenes/test/phase2_battle_sandbox.tscn`
- `res://presentation/sandbox/phase2/...`
- `res://gameplay/sandbox/phase2/...`

## Formal Replacements

- 正式前台入口：`res://scenes/front/room_scene.tscn`
- 正式加载场景：`res://scenes/front/loading_scene.tscn`
- 正式战斗入口：`res://scenes/battle/battle_main.tscn`

## Phase3 Runtime Entry

正式 Battle 运行链路：
- `res://app/flow/front_flow_controller.gd`
- `res://network/session/battle_session_adapter.gd`
- `res://gameplay/battle/runtime/battle_bootstrap.gd`
- `res://presentation/battle/bridge/presentation_bridge.gd`

## Debugging Rule

如果后续需要调试正式战斗：
1. 从 `room_scene.tscn` 进入完整主链路
2. 或直接运行 `battle_main.tscn` 做 Battle 层局部验证
3. 不再创建、恢复或依赖任何 Phase2 sandbox 场景

## Contract

- 正式 battle scene path 不得包含 `sandbox`
- 正式 flow / session / presentation 不得反向依赖 sandbox 组件
- 测试中如果出现 `sandbox`，只能用于“确保不再引用 sandbox”的负向断言
