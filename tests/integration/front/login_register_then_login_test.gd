extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")
const RegisterRequestScript = preload("res://app/front/auth/register_request.gd")
const LoginResultScript = preload("res://app/front/auth/login_result.gd")
const RegisterResultScript = preload("res://app/front/auth/register_result.gd")



class FakeAuthGateway:
	extends "res://app/front/auth/auth_gateway.gd"

	var accounts: Dictionary = {}

	func register(request):
		await _yield_once()
		var result = RegisterResultScript.new()
		if request == null or String(request.account).is_empty():
			result.ok = false
			result.error_code = "REGISTER_INVALID"
			result.user_message = "register invalid"
			return result
		accounts[String(request.account)] = {
			"password": String(request.password),
			"nickname": String(request.nickname),
		}
		result.ok = true
		result.account_id = "account_%s" % request.account
		result.profile_id = "profile_%s" % request.account
		result.display_name = String(request.nickname)
		result.auth_mode = "account"
		result.access_token = "access_register_%s" % request.account
		result.refresh_token = "refresh_register_%s" % request.account
		result.device_session_id = "dsess_%s" % request.account
		result.access_expire_at_unix_sec = int(Time.get_unix_time_from_system()) + 300
		result.refresh_expire_at_unix_sec = int(Time.get_unix_time_from_system()) + 3600
		result.session_state = "active"
		return result

	func login(request):
		await _yield_once()
		var record: Dictionary = accounts.get(String(request.account), {})
		if record.is_empty() or String(record.get("password", "")) != String(request.password):
			return LoginResultScript.fail("LOGIN_FAILED", "login failed")
		return LoginResultScript.success(
			"account_%s" % request.account,
			"profile_%s" % request.account,
			String(record.get("nickname", "")),
			"account",
			"access_login_%s" % request.account,
			"refresh_login_%s" % request.account,
			"dsess_%s" % request.account,
			int(Time.get_unix_time_from_system()) + 300,
			int(Time.get_unix_time_from_system()) + 3600,
			"active",
			false,
			"login success"
		)

	func _yield_once() -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.process_frame


class FakeProfileGateway:
	extends RefCounted

	var accounts: Dictionary = {}

	func fetch_my_profile(access_token: String) -> Dictionary:
		await _yield_once()
		var account_key := _extract_account(access_token)
		var record: Dictionary = accounts.get(account_key, {})
		return {
			"ok": true,
			"profile_id": "profile_%s" % account_key,
			"account_id": "account_%s" % account_key,
			"nickname": String(record.get("nickname", "")),
			"default_character_id": "character_default",
			"default_bubble_style_id": "bubble_style_default",
			"preferred_mode_id": "mode_default",
			"preferred_map_id": "map_default",
			"preferred_rule_set_id": "rule_default",
			"owned_character_ids": ["character_default"],
			"owned_bubble_style_ids": ["bubble_style_default"],
			"profile_version": 1,
			"owned_asset_revision": 1,
		}

	func _yield_once() -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.process_frame

	func _extract_account(access_token: String) -> String:
		var token := String(access_token)
		var marker := token.rfind("_")
		if marker < 0:
			return token
		return token.substr(marker + 1)


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	var auth_gateway := FakeAuthGateway.new()
	var profile_gateway := FakeProfileGateway.new()
	runtime.auth_gateway = auth_gateway
	runtime.profile_gateway = profile_gateway
	runtime.login_use_case.configure(
		runtime.auth_gateway,
		runtime.auth_session_state,
		runtime.auth_session_repository,
		runtime.profile_gateway,
		runtime.profile_repository,
		runtime.front_settings_repository,
		runtime.player_profile_state,
		runtime.front_settings_state
	)
	runtime.register_use_case.configure(runtime)

	var register_request := RegisterRequestScript.new()
	register_request.account = "demo"
	register_request.password = "pw123"
	register_request.nickname = "DemoUser"
	register_request.server_host = "127.0.0.1"
	register_request.server_port = 8080
	var register_result: Dictionary = await runtime.register_use_case.register(register_request)
	profile_gateway.accounts = auth_gateway.accounts.duplicate(true)

	var login_request := LoginRequestScript.new()
	login_request.account = "demo"
	login_request.password = "pw123"
	login_request.server_host = "127.0.0.1"
	login_request.server_port = 8080
	var login_result: Dictionary = await runtime.login_use_case.login(login_request)

	var prefix := "login_register_then_login_test"
	var ok := true
	ok = qqt_check(bool(register_result.get("ok", false)), "register should succeed", prefix) and ok
	ok = qqt_check(bool(login_result.get("ok", false)), "login should succeed after register", prefix) and ok
	ok = qqt_check(String(runtime.auth_session_state.account_id) == "account_demo", "login should write account id", prefix) and ok
	ok = qqt_check(String(runtime.player_profile_state.nickname) == "DemoUser", "login should sync registered nickname", prefix) and ok

	runtime.queue_free()

