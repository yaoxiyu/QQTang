class_name RefreshSessionResult
extends RefCounted

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var account_id: String = ""
var profile_id: String = ""
var display_name: String = ""
var auth_mode: String = ""
var access_token: String = ""
var refresh_token: String = ""
var device_session_id: String = ""
var access_expire_at_unix_sec: int = 0
var refresh_expire_at_unix_sec: int = 0
var session_state: String = "logged_out"
var validation_bypassed: bool = false


static func fail(p_error_code: String, p_user_message: String) -> RefreshSessionResult:
	var result := RefreshSessionResult.new()
	result.ok = false
	result.error_code = p_error_code
	result.user_message = p_user_message
	return result


static func success_from_dict(data: Dictionary) -> RefreshSessionResult:
	var result := RefreshSessionResult.new()
	result.ok = bool(data.get("ok", false))
	result.error_code = String(data.get("error_code", ""))
	result.user_message = String(data.get("user_message", ""))
	result.account_id = String(data.get("account_id", ""))
	result.profile_id = String(data.get("profile_id", ""))
	result.display_name = String(data.get("display_name", ""))
	result.auth_mode = String(data.get("auth_mode", ""))
	result.access_token = String(data.get("access_token", ""))
	result.refresh_token = String(data.get("refresh_token", ""))
	result.device_session_id = String(data.get("device_session_id", ""))
	result.access_expire_at_unix_sec = int(data.get("access_expire_at_unix_sec", 0))
	result.refresh_expire_at_unix_sec = int(data.get("refresh_expire_at_unix_sec", 0))
	result.session_state = String(data.get("session_state", "active"))
	result.validation_bypassed = bool(data.get("validation_bypassed", false))
	return result
