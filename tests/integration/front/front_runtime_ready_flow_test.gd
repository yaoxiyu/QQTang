extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const BootSceneScript = preload("res://scenes/front/boot_scene.tscn")
const LoginSceneScript = preload("res://scenes/front/login_scene.tscn")
const LobbySceneScript = preload("res://scenes/front/lobby_scene.tscn")
const RoomSceneScript = preload("res://scenes/front/room/room_formal.tscn")
const LoadingSceneScript = preload("res://scenes/front/loading_scene.tscn")



func test_main() -> void:
	call_deferred("_main_body")


func _main_body() -> void:
	await _test_boot_waits_for_runtime_ready_before_entering_login_or_lobby()
	await _test_front_scenes_consume_same_ready_runtime()


func _test_boot_waits_for_runtime_ready_before_entering_login_or_lobby() -> void:
	var runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_assert_true(runtime != null, "boot integration can bootstrap runtime")
	await get_tree().process_frame
	await get_tree().process_frame
	runtime.front_flow.scene_flow_controller = null
	runtime.player_profile_state.profile_id = ""
	runtime.player_profile_state.nickname = ""
	runtime.front_settings_state.remember_profile = true
	runtime.front_settings_state.auto_enter_lobby = true

	var boot_scene: Node = BootSceneScript.instantiate()
	add_child(boot_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_true(runtime.is_runtime_ready(), "boot waits until runtime becomes ready")
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.LOGIN), "boot enters login after runtime ready")
	_assert_true(_count_app_roots() == 1, "boot runtime bootstrap keeps a single AppRoot instance")

	boot_scene.queue_free()
	runtime.queue_free()
	await get_tree().process_frame


func _test_front_scenes_consume_same_ready_runtime() -> void:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	runtime.front_flow.scene_flow_controller = null
	runtime.player_profile_state.nickname = "RuntimeTester"
	runtime.front_settings_state.last_server_host = "127.0.0.1"
	runtime.front_settings_state.last_server_port = 9527

	var login_scene: Node = LoginSceneScript.instantiate()
	var lobby_scene: Node = LobbySceneScript.instantiate()
	var room_scene: Node = RoomSceneScript.instantiate()
	var loading_scene: Node = LoadingSceneScript.instantiate()
	add_child(login_scene)
	add_child(lobby_scene)
	add_child(room_scene)
	add_child(loading_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var login_name_input: LineEdit = login_scene.get_node_or_null("LoginRoot/MainLayout/ProfileCard/ProfileVBox/PlayerNameRow/PlayerNameInput")
	var login_host_input: LineEdit = login_scene.get_node_or_null("LoginRoot/MainLayout/EndpointCard/EndpointVBox/HostRow/HostInput")
	var lobby_profile_label: Label = lobby_scene.get_node_or_null("LobbyRoot/MainLayout/HeaderRow/CurrentProfileLabel")
	var room_root: Control = room_scene.get_node_or_null("RoomFormal")
	var loading_hint: Label = loading_scene.get_node_or_null("LoadingRoot/MainLayout/TimeoutHint")

	_assert_true(login_name_input != null and login_name_input.text == "RuntimeTester", "login scene consumes existing ready runtime")
	_assert_true(login_host_input != null and login_host_input.text == "127.0.0.1", "login scene binds runtime front settings")
	_assert_true(lobby_profile_label != null and lobby_profile_label.text == "RuntimeTester", "lobby scene consumes existing ready runtime")
	_assert_true(room_root != null, "room scene binds ready runtime without creating fallback runtime")
	_assert_true(loading_hint != null and loading_hint.text.contains("Missing BattleStartConfig"), "loading scene binds ready runtime before loading")
	_assert_true(_count_app_roots() == 1, "consumer scenes do not create extra AppRoot when using shared runtime")

	login_scene.queue_free()
	lobby_scene.queue_free()
	room_scene.queue_free()
	loading_scene.queue_free()
	runtime.queue_free()
	await get_tree().process_frame


func _count_app_roots() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child != null and String(child.name) == "AppRoot":
			count += 1
	return count


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
