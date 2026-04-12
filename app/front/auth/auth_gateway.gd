class_name AuthGateway
extends RefCounted


func register(request: RegisterRequest) -> RegisterResult:
	return RegisterResult.fail("NOT_IMPLEMENTED", "AuthGateway.register not implemented")


func login(request: LoginRequest) -> LoginResult:
	return LoginResult.fail("NOT_IMPLEMENTED", "AuthGateway.login not implemented")


func refresh_session(refresh_token: String, device_session_id: String) -> RefreshSessionResult:
	return RefreshSessionResult.fail("NOT_IMPLEMENTED", "AuthGateway.refresh_session not implemented")


func logout(access_token: String, refresh_token: String, device_session_id: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "AuthGateway.logout not implemented",
	}


func get_current_session(access_token: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "AuthGateway.get_current_session not implemented",
	}
