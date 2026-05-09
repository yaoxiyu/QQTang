extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")



class FakeProfileGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func fetch_my_profile(_access_token: String) -> Dictionary:
		return {
			"ok": true,
			"profile_id": "profile_assets",
			"account_id": "account_assets",
			"nickname": "AssetUser",
			"default_character_id": "hero_001",
			"default_bubble_style_id": "bubble_normal",
			"preferred_mode_id": "team_score",
			"preferred_map_id": "map_01",
			"preferred_rule_set_id": "rule_team_score",
			"owned_character_ids": ["hero_001"],
			"owned_bubble_style_ids": ["bubble_normal"],
			"profile_version": 7,
			"owned_asset_revision": 11,
		}


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.profile_gateway = FakeProfileGateway.new()
	runtime.auth_session_state.access_token = "access_assets"
	runtime.lobby_use_case.configure(
		runtime,
		runtime.auth_session_state,
		runtime.player_profile_state,
		runtime.front_settings_state,
		runtime.practice_room_factory,
		runtime.auth_session_repository,
		runtime.logout_use_case,
		runtime.profile_gateway,
		runtime.room_ticket_gateway
	)
	var result: Dictionary = runtime.lobby_use_case.refresh_profile()

	var prefix := "lobby_fetch_profile_and_owned_assets_test"
	var ok := true
	ok = qqt_check(bool(result.get("ok", false)), "refresh_profile should succeed", prefix) and ok
	ok = qqt_check(runtime.player_profile_state.owned_character_ids == ["hero_001"], "refresh_profile should sync owned characters", prefix) and ok
	ok = qqt_check(runtime.player_profile_state.owned_bubble_style_ids == ["bubble_normal"], "refresh_profile should sync owned bubbles", prefix) and ok
	ok = qqt_check(String(runtime.player_profile_state.profile_source) == "cloud_cache", "refresh_profile should mark cloud cache source", prefix) and ok

	runtime.queue_free()


