class_name PassThroughAuthGateway
extends AuthGateway

func register(request: RegisterRequest) -> RegisterResult:
	await _yield_once()
	if request == null:
		return RegisterResult.fail("REGISTER_REQUEST_INVALID", "Register request is missing")
	var nickname := request.nickname.strip_edges()
	if nickname.is_empty():
		return RegisterResult.fail("REGISTER_NICKNAME_REQUIRED", "Nickname is required")
	return RegisterResult.success_from_dict({
		"ok": true,
		"account_id": "guest::%s" % request.account.strip_edges(),
		"profile_id": "local_guest",
		"display_name": nickname,
		"auth_mode": "pass_through",
		"session_state": "guest",
		"validation_bypassed": true,
		"user_message": "Register succeeded",
	})


func login(request: LoginRequest) -> LoginResult:
	await _yield_once()
	if request == null:
		return LoginResult.fail("LOGIN_REQUEST_INVALID", "Login request is missing")

	var nickname := request.nickname.strip_edges()
	if nickname.is_empty():
		return LoginResult.fail("LOGIN_NICKNAME_REQUIRED", "Nickname is required")

	var profile_id := request.profile_id.strip_edges()
	if profile_id.is_empty():
		profile_id = "local_guest"

	return LoginResult.success(
		"guest::%s" % profile_id,
		profile_id,
		nickname,
		"pass_through",
		"",
		"",
		"",
		0,
		0,
		"guest",
		true,
		"Login succeeded"
	)


func refresh_session(refresh_token: String, device_session_id: String) -> RefreshSessionResult:
	await _yield_once()
	return RefreshSessionResult.success_from_dict({
		"ok": true,
		"account_id": "guest::local_guest",
		"profile_id": "local_guest",
		"display_name": "Guest",
		"auth_mode": "pass_through",
		"access_token": "",
		"refresh_token": refresh_token,
		"device_session_id": device_session_id,
		"session_state": "guest",
		"validation_bypassed": true,
		"user_message": "Guest session refresh bypassed",
	})


func logout(access_token: String, refresh_token: String, device_session_id: String) -> Dictionary:
	await _yield_once()
	return {
		"ok": true,
		"error_code": "",
		"user_message": "Guest session logout bypassed",
		"session_state": "logged_out",
	}


func get_current_session(access_token: String) -> Dictionary:
	await _yield_once()
	return {
		"ok": true,
		"error_code": "",
		"user_message": "Guest session validation bypassed",
		"account_id": "guest::local_guest",
		"profile_id": "local_guest",
		"display_name": "Guest",
		"auth_mode": "pass_through",
		"device_session_id": "",
		"session_state": "guest",
		"validation_bypassed": true,
	}


func _yield_once() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
