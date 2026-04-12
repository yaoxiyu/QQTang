extends Node

const LoginUseCaseScript = preload("res://app/front/auth/login_use_case.gd")
const LoginRequestScript = preload("res://app/front/auth/login_request.gd")
const LoginResultScript = preload("res://app/front/auth/login_result.gd")
const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")


class FakeAuthGateway:
	extends AuthGateway

	func login(_request):
		return LoginResultScript.success(
			"account_http",
			"profile_http",
			"HttpUser",
			"account",
			"access_http",
			"refresh_http",
			"dsess_http",
			111,
			222,
			"active",
			false,
			"ok"
		)


class FakeProfileGateway:
	extends RefCounted

	func fetch_my_profile(_access_token: String) -> Dictionary:
		return {
			"ok": true,
			"profile_id": "profile_http",
			"account_id": "account_http",
			"nickname": "HttpUser",
			"default_character_id": "character_default",
			"default_character_skin_id": "",
			"default_bubble_style_id": "bubble_style_default",
			"default_bubble_skin_id": "",
			"preferred_mode_id": "mode_default",
			"preferred_map_id": "map_default",
			"preferred_rule_set_id": "rule_default",
			"owned_character_ids": ["character_default"],
			"owned_character_skin_ids": [""],
			"owned_bubble_style_ids": ["bubble_style_default"],
			"owned_bubble_skin_ids": [""],
			"profile_version": 2,
			"owned_asset_revision": 3,
		}


class FakeAuthSessionRepository:
	extends RefCounted

	var last_saved = null

	func save_session(state) -> bool:
		last_saved = state.duplicate_deep()
		return true


class FakeProfileRepository:
	extends ProfileRepository

	var last_saved = null

	func save_profile(profile) -> bool:
		last_saved = profile.duplicate_deep()
		return true


class FakeFrontSettingsRepository:
	extends FrontSettingsRepository

	var save_count: int = 0

	func save_settings(_settings) -> bool:
		save_count += 1
		return true


func _ready() -> void:
	var use_case := LoginUseCaseScript.new()
	var auth_session := AuthSessionStateScript.new()
	var auth_session_repository := FakeAuthSessionRepository.new()
	var profile_repository := FakeProfileRepository.new()
	var front_settings_repository := FakeFrontSettingsRepository.new()
	var player_profile := PlayerProfileStateScript.new()
	var front_settings := FrontSettingsStateScript.new()
	use_case.configure(
		FakeAuthGateway.new(),
		auth_session,
		auth_session_repository,
		FakeProfileGateway.new(),
		profile_repository,
		front_settings_repository,
		player_profile,
		front_settings
	)

	var request := LoginRequestScript.new()
	request.account = "demo"
	request.password = "pw"
	request.server_host = "127.0.0.1"
	request.server_port = 8080
	var result := use_case.login(request)

	var prefix := "login_use_case_http_test"
	var ok := true
	ok = TestAssert.is_true(bool(result.get("ok", false)), "login should succeed", prefix) and ok
	ok = TestAssert.is_true(String(auth_session.account_id) == "account_http", "login should write account id", prefix) and ok
	ok = TestAssert.is_true(String(auth_session.profile_id) == "profile_http", "login should write profile id", prefix) and ok
	ok = TestAssert.is_true(String(auth_session.device_session_id) == "dsess_http", "login should write device session", prefix) and ok
	ok = TestAssert.is_true(String(player_profile.nickname) == "HttpUser", "login should sync profile nickname", prefix) and ok
	ok = TestAssert.is_true(player_profile.owned_character_ids == ["character_default"], "login should sync owned characters", prefix) and ok
	ok = TestAssert.is_true(auth_session_repository.last_saved != null, "login should persist auth session", prefix) and ok
	ok = TestAssert.is_true(profile_repository.last_saved != null, "login should persist profile cache", prefix) and ok
	ok = TestAssert.is_true(front_settings_repository.save_count == 1, "login should persist front settings", prefix) and ok

	if ok:
		print("login_use_case_http_test: PASS")
