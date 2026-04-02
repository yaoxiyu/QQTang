# Cleanup Baseline

## Git Baseline
- Current branch before cleanup: `main`
- Cleanup branch: `refactor/source-layout-cleanup`
- Working tree state before edits: clean
- File tree snapshot: `docs/tmp_before_cleanup_tree.txt`

## Main Scene
- `project.godot`
- `run/main_scene = "uid://corlic5dxf6m7"`
- Resolved scene path: `res://scenes/front/room_scene.tscn`

## Key Scenes
- Front loading: `res://scenes/front/loading_scene.tscn`
- Front room: `res://scenes/front/room_scene.tscn`
- Battle main: `res://scenes/battle/battle_main.tscn`
- Network bootstrap: `res://scenes/network/network_bootstrap_scene.tscn`
- Dedicated server: `res://scenes/network/dedicated_server_scene.tscn`
- Sandbox prototype: `res://scenes/sandbox/simulation_prototype.tscn`

## Key Entry Scripts
- App runtime root: `res://app/flow/app_runtime_root.gd`
- Front flow controller: `res://app/flow/front_flow_controller.gd`
- Scene flow controller: `res://app/flow/scene_flow_controller.gd`
- Runtime debug tools: `res://app/debug/runtime_debug_tools.gd`
- Network room session controller: `res://network/session/room_session_controller.gd`
- Match start coordinator: `res://network/session/match_start_coordinator.gd`
- Battle session adapter: `res://network/session/battle_session_adapter.gd`
- Client room runtime: `res://network/runtime/client_room_runtime.gd`
- Battle bootstrap: `res://gameplay/battle/runtime/battle_bootstrap.gd`
- Presentation bridge: `res://presentation/battle/bridge/presentation_bridge.gd`

## Scene Script Attachments

### `res://scenes/front/loading_scene.tscn`
- `res://scenes/front/loading_scene_controller.gd`

### `res://scenes/front/room_scene.tscn`
- `res://scenes/front/room_scene_controller.gd`
- `res://presentation/battle/hud/room_hud_controller.gd`

### `res://scenes/battle/battle_main.tscn`
- `res://scenes/battle/battle_main_controller.gd`
- `res://gameplay/battle/runtime/battle_bootstrap.gd`
- `res://presentation/battle/bridge/presentation_bridge.gd`
- `res://presentation/battle/hud/battle_hud_controller.gd`
- `res://presentation/battle/hud/countdown_panel.gd`
- `res://presentation/battle/hud/player_status_panel.gd`
- `res://presentation/battle/hud/network_status_panel.gd`
- `res://presentation/battle/hud/match_message_panel.gd`
- `res://presentation/battle/scene/map_view_controller.gd`
- `res://presentation/battle/scene/battle_camera_controller.gd`
- `res://presentation/battle/scene/spawn_fx_controller.gd`

### `res://scenes/battle/settlement_popup.tscn`
- `res://presentation/battle/hud/settlement_controller.gd`

### `res://scenes/network/network_bootstrap_scene.tscn`
- `res://network/runtime/network_bootstrap.gd`

### `res://scenes/network/dedicated_server_scene.tscn`
- `res://network/runtime/dedicated_server_bootstrap.gd`

### `res://scenes/sandbox/simulation_prototype.tscn`
- `res://gameplay/simulation/runtime/simulation_runner_node.gd`
- `res://presentation/runtime/presentation_bridge.gd`
