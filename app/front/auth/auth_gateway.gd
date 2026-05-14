class_name AuthGateway
extends RefCounted


func register(request: RegisterRequest) -> RegisterResult:
	await _yield_once()
	return RegisterResult.fail("NOT_IMPLEMENTED", "AuthGateway.register not implemented")


func login(request: LoginRequest) -> LoginResult:
	await _yield_once()
	return LoginResult.fail("NOT_IMPLEMENTED", "AuthGateway.login not implemented")


func refresh_session(refresh_token: String, device_session_id: String) -> RefreshSessionResult:
	await _yield_once()
	return RefreshSessionResult.fail("NOT_IMPLEMENTED", "AuthGateway.refresh_session not implemented")


func logout(access_token: String, refresh_token: String, device_session_id: String) -> Dictionary:
	await _yield_once()
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "AuthGateway.logout not implemented",
	}


func get_current_session(access_token: String) -> Dictionary:
	await _yield_once()
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "AuthGateway.get_current_session not implemented",
	}


func _yield_once() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
