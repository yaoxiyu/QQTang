extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const RefreshSessionResultScript = preload("res://app/front/auth/refresh_session_result.gd")



class FakeAuthGateway:
	extends RefCounted

	var last_base_url: String = ""

	func configure_base_url(base_url: String) -> void:
		last_base_url = base_url

	func refresh_session(_refresh_token: String, device_session_id: String):
		var result = RefreshSessionResultScript.new()
		result.ok = true
		result.account_id = "account_refresh"
		result.profile_id = "profile_refresh"
		result.display_name = "RefreshUser"
		result.auth_mode = "account"
		result.access_token = "access_refreshed"
		result.refresh_token = "refresh_refreshed"
		result.device_session_id = device_session_id
		result.access_expire_at_unix_sec = int(Time.get_unix_time_from_system()) + 300
		result.refresh_expire_at_unix_sec = int(Time.get_unix_time_from_system()) + 3600
		result.session_state = "active"
		return result


class FakeProfileGateway:
	extends RefCounted

	var last_base_url: String = ""

	func configure_base_url(base_url: String) -> void:
		last_base_url = base_url

	func fetch_my_profile(_access_token: String) -> Dictionary:
		return {
			"ok": true,
			"profile_id": "profile_refresh",
			"account_id": "account_refresh",
			"nickname": "RefreshUser",
			"default_character_id": "character_default",
			"default_bubble_style_id": "bubble_style_default",
			"preferred_mode_id": "mode_default",
			"preferred_map_id": "map_default",
			"preferred_rule_set_id": "rule_default",
			"owned_character_ids": ["character_default"],
			"owned_bubble_style_ids": ["bubble_style_default"],
			"profile_version": 2,
			"owned_asset_revision": 3,
		}


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.auth_gateway = FakeAuthGateway.new()
	runtime.profile_gateway = FakeProfileGateway.new()
	runtime.auth_session_restore_use_case.configure(runtime)
	runtime.front_settings_state.last_server_host = "127.0.0.1"
	runtime.front_settings_state.last_server_port = 8080
	runtime.auth_session_state.refresh_token = "refresh_old"
	runtime.auth_session_state.device_session_id = "dsess_refresh"
	runtime.auth_session_state.access_expire_at_unix_sec = int(Time.get_unix_time_from_system()) - 10
	runtime.auth_session_state.refresh_expire_at_unix_sec = int(Time.get_unix_time_from_system()) + 3600

	var result: Dictionary = runtime.auth_session_restore_use_case.restore_on_boot()

	var prefix := "boot_refresh_session_to_lobby_test"
	var ok := true
	ok = qqt_check(bool(result.get("ok", false)), "restore should succeed", prefix) and ok
	ok = qqt_check(String(result.get("next_route", "")) == "lobby", "restore should route to lobby", prefix) and ok
	ok = qqt_check(String(runtime.auth_session_state.access_token) == "access_refreshed", "restore should write refreshed access token", prefix) and ok
	ok = qqt_check(String(runtime.player_profile_state.nickname) == "RefreshUser", "restore should sync profile", prefix) and ok

	runtime.queue_free()


