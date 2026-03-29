# Canonical Paths For Phase3

本文件定义 Phase3 收尾后的正式实现路径与 legacy wrapper 边界。

## Canonical Paths

### Front Flow
- `res://app/flow/app_runtime_root.gd`
- `res://app/flow/front_flow_controller.gd`
- `res://app/flow/scene_flow_controller.gd`

### Session Layer
- `res://network/session/room_session_controller.gd`
- `res://network/session/match_start_coordinator.gd`
- `res://network/session/battle_session_adapter.gd`

### Battle Presentation
- `res://presentation/battle/bridge/presentation_bridge.gd`
- `res://presentation/battle/bridge/battle_event_router.gd`
- `res://presentation/battle/bridge/state_to_view_mapper.gd`
- `res://presentation/battle/bridge/actor_registry.gd`
- `res://presentation/battle/hud/battle_hud_controller.gd`
- `res://presentation/battle/hud/room_hud_controller.gd`
- `res://presentation/battle/hud/settlement_controller.gd`
- `res://presentation/battle/scene/battle_camera_controller.gd`
- `res://presentation/battle/scene/map_view_controller.gd`
- `res://presentation/battle/scene/spawn_fx_controller.gd`

### Runtime / Battle Config
- `res://gameplay/battle/runtime/battle_bootstrap.gd`
- `res://gameplay/battle/runtime/battle_context.gd`
- `res://gameplay/battle/runtime/battle_result.gd`
- `res://gameplay/battle/config/battle_start_config.gd`
- `res://gameplay/battle/config/room_snapshot.gd`
- `res://gameplay/battle/config/room_member_state.gd`

### Formal Scenes
- `res://scenes/front/room_scene.tscn`
- `res://scenes/front/loading_scene.tscn`
- `res://scenes/battle/battle_main.tscn`
- `res://scenes/battle/settlement_popup.tscn`

## Legacy Wrappers

下面这些路径仅用于兼容旧引用，禁止在其中新增业务逻辑：
- `res://gameplay/front/flow/app_runtime_root.gd`
- `res://gameplay/front/flow/front_flow_controller.gd`
- `res://gameplay/front/flow/scene_flow_controller.gd`
- `res://gameplay/network/session/room_session_controller.gd`
- `res://gameplay/network/session/match_start_coordinator.gd`
- `res://gameplay/network/session/battle_session_adapter.gd`

## AI / Human Editing Rule

1. 以后修改前台流程，只改 `res://app/flow/...`
2. 以后修改房间/开局/会话，只改 `res://network/session/...`
3. 以后修改 Battle 表现，只改 `res://presentation/battle/...`
4. 不要在 legacy wrapper 内施工
5. 正式场景与测试默认使用 canonical path
