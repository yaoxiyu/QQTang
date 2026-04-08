extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_boot_decision_can_route_to_login_or_lobby()
	_test_pass_through_login_updates_runtime_state()


func _test_boot_decision_can_route_to_login_or_lobby() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	runtime.player_profile_state.profile_id = ""
	runtime.player_profile_state.nickname = ""
	runtime.front_settings_state.remember_profile = true
	runtime.front_settings_state.auto_enter_lobby = true
	var should_enter_lobby := _should_boot_enter_lobby(runtime)
	_assert_true(not should_enter_lobby, "boot routes to login when remembered profile is invalid")

	runtime.player_profile_state.profile_id = "p_test"
	runtime.player_profile_state.nickname = "Tester"
	should_enter_lobby = _should_boot_enter_lobby(runtime)
	_assert_true(should_enter_lobby, "boot routes to lobby when remembered profile is valid")

	runtime.queue_free()


func _test_pass_through_login_updates_runtime_state() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var request := LoginRequestScript.new()
	request.profile_id = "guest_profile"
	request.nickname = "FrontTester"
	request.server_host = "127.0.0.1"
	request.server_port = 9000

	var result: Dictionary = runtime.login_use_case.login(request)
	_assert_true(bool(result.get("ok", false)), "pass-through login succeeds")
	_assert_true(
		runtime.auth_session_state.login_status == runtime.auth_session_state.LoginStatus.LOGGED_IN,
		"auth session enters logged-in state"
	)
	_assert_true(String(runtime.player_profile_state.nickname) == "FrontTester", "login writes profile nickname")
	_assert_true(String(runtime.front_settings_state.last_server_host) == "127.0.0.1", "login persists last server host")

	runtime.front_flow.enter_lobby()
	_assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.LOBBY), "front flow can enter lobby after login")

	runtime.queue_free()


func _should_boot_enter_lobby(runtime: Node) -> bool:
	if runtime == null:
		return false
	var settings = runtime.front_settings_state
	var profile = runtime.player_profile_state
	return settings != null \
		and profile != null \
		and bool(settings.remember_profile) \
		and bool(settings.auto_enter_lobby) \
		and not String(profile.profile_id).strip_edges().is_empty() \
		and not String(profile.nickname).strip_edges().is_empty()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
