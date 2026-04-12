class_name LoginResult
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
var validation_bypassed: bool = true
var session_state: String = "logged_out"


static func success(
	p_account_id: String,
	p_profile_id: String,
	p_display_name: String,
	p_auth_mode: String,
	p_access_token: String = "",
	p_refresh_token: String = "",
	p_device_session_id: String = "",
	p_access_expire_at_unix_sec: int = 0,
	p_refresh_expire_at_unix_sec: int = 0,
	p_session_state: String = "active",
	p_validation_bypassed: bool = true,
	p_user_message: String = ""
) -> LoginResult:
	var result := LoginResult.new()
	result.ok = true
	result.account_id = p_account_id
	result.profile_id = p_profile_id
	result.display_name = p_display_name
	result.auth_mode = p_auth_mode
	result.access_token = p_access_token
	result.refresh_token = p_refresh_token
	result.device_session_id = p_device_session_id
	result.access_expire_at_unix_sec = p_access_expire_at_unix_sec
	result.refresh_expire_at_unix_sec = p_refresh_expire_at_unix_sec
	result.session_state = p_session_state
	result.validation_bypassed = p_validation_bypassed
	result.user_message = p_user_message
	return result


static func fail(p_error_code: String, p_user_message: String) -> LoginResult:
	var result := LoginResult.new()
	result.ok = false
	result.error_code = p_error_code
	result.user_message = p_user_message
	result.validation_bypassed = true
	return result
