class_name HttpAuthGateway
extends AuthGateway

const RegisterResultScript = preload("res://app/front/auth/register_result.gd")
const RefreshSessionResultScript = preload("res://app/front/auth/refresh_session_result.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func register(request: RegisterRequest) -> RegisterResult:
	if request == null:
		return RegisterResultScript.fail("REGISTER_REQUEST_INVALID", "Register request is missing")
	service_base_url = _build_base_url(request.server_host, request.server_port)
	return RegisterResultScript.success_from_dict(
		_request_json(
			service_base_url + "/api/v1/auth/register",
			HTTPClient.METHOD_POST,
			{
				"account": request.account,
				"password": request.password,
				"nickname": request.nickname,
				"client_platform": request.client_platform,
			}
		)
	)


func login(request: LoginRequest) -> LoginResult:
	if request == null:
		return LoginResult.fail("LOGIN_REQUEST_INVALID", "Login request is missing")
	service_base_url = _build_base_url(request.server_host, request.server_port)
	var response := _request_json(
		service_base_url + "/api/v1/auth/login",
		HTTPClient.METHOD_POST,
		{
			"account": request.account,
			"password": request.password,
			"client_platform": request.client_platform,
		}
	)
	if not bool(response.get("ok", false)):
		return LoginResult.fail(String(response.get("error_code", "LOGIN_FAILED")), String(response.get("message", response.get("user_message", "Login failed"))))
	return LoginResult.success(
		String(response.get("account_id", "")),
		String(response.get("profile_id", "")),
		String(response.get("display_name", "")),
		String(response.get("auth_mode", "")),
		String(response.get("access_token", "")),
		String(response.get("refresh_token", "")),
		String(response.get("device_session_id", "")),
		int(response.get("access_expire_at_unix_sec", 0)),
		int(response.get("refresh_expire_at_unix_sec", 0)),
		String(response.get("session_state", "active")),
		bool(response.get("validation_bypassed", false)),
		String(response.get("message", "Login succeeded"))
	)


func refresh_session(refresh_token: String, device_session_id: String) -> RefreshSessionResult:
	return RefreshSessionResultScript.success_from_dict(
		_request_json(
			_require_base_url() + "/api/v1/auth/refresh",
			HTTPClient.METHOD_POST,
			{
				"refresh_token": refresh_token,
				"device_session_id": device_session_id,
			}
		)
	)


func logout(access_token: String, refresh_token: String, device_session_id: String) -> Dictionary:
	return _request_json(
		_require_base_url() + "/api/v1/auth/logout",
		HTTPClient.METHOD_POST,
		{
			"refresh_token": refresh_token,
			"device_session_id": device_session_id,
		},
		["Authorization: Bearer %s" % access_token]
	)


func get_current_session(access_token: String) -> Dictionary:
	return _request_json(
		_require_base_url() + "/api/v1/auth/session",
		HTTPClient.METHOD_GET,
		{},
		["Authorization: Bearer %s" % access_token]
	)


func _build_base_url(server_host: String, server_port: int) -> String:
	var host := server_host.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port := server_port
	if port <= 0:
		port = 18080
	return "http://%s:%d" % [host, port]


func _require_base_url() -> String:
	return service_base_url.strip_edges()


func _request_json(url: String, method: int, body: Dictionary, extra_headers: Array = []) -> Dictionary:
	if url.strip_edges().is_empty():
		return {
			"ok": false,
			"error_code": "AUTH_HTTP_URL_MISSING",
			"user_message": "Auth HTTP url is missing",
		}
	var options := HttpRequestOptionsScript.new()
	options.method = method
	options.url = url
	options.log_tag = "front.auth.gateway"
	var headers := PackedStringArray(["Content-Type: application/json"])
	for header in extra_headers:
		headers.append(String(header))
	options.headers = headers
	options.body_text = "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var response = HttpRequestExecutorScript.execute(options)
	if response.error_code == "HTTP_URL_INVALID":
		return {
			"ok": false,
			"error_code": "AUTH_HTTP_URL_INVALID",
			"user_message": "Auth HTTP url is invalid",
		}
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return {
			"ok": false,
			"error_code": "AUTH_HTTP_CONNECT_FAILED",
			"user_message": "Failed to connect auth service",
		}
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return {
			"ok": false,
			"error_code": "AUTH_HTTP_REQUEST_FAILED",
			"user_message": "Failed to send auth request",
		}
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return {
			"ok": false,
			"error_code": "AUTH_HTTP_EMPTY_RESPONSE",
			"user_message": "Auth service returned empty response",
		}
	if not (response.body_json is Dictionary):
		return {
			"ok": false,
			"error_code": "AUTH_HTTP_RESPONSE_INVALID",
			"user_message": "Auth service returned invalid response",
		}
	var response_body: Dictionary = response.body_json
	if not response_body.has("user_message") and response_body.has("message"):
		response_body["user_message"] = response_body.get("message", "")
	response_body["status_code"] = response.status_code
	return response_body
