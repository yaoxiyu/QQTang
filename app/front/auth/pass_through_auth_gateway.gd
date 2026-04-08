class_name PassThroughAuthGateway
extends AuthGateway

func login(request: LoginRequest) -> LoginResult:
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
		nickname,
		"pass_through",
		true,
		"Login succeeded"
	)
