class_name AuthSessionState
extends RefCounted

enum LoginStatus {
	LOGGED_OUT = 0,
	LOGGED_IN = 1,
}

var login_status: int = LoginStatus.LOGGED_OUT
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
var validation_bypassed: bool = true


func clear() -> void:
	login_status = LoginStatus.LOGGED_OUT
	account_id = ""
	profile_id = ""
	display_name = ""
	auth_mode = ""
	access_token = ""
	refresh_token = ""
	device_session_id = ""
	access_expire_at_unix_sec = 0
	refresh_expire_at_unix_sec = 0
	session_state = "logged_out"
	validation_bypassed = true


func to_dict() -> Dictionary:
	return {
		"login_status": login_status,
		"account_id": account_id,
		"profile_id": profile_id,
		"display_name": display_name,
		"auth_mode": auth_mode,
		"access_token": access_token,
		"refresh_token": refresh_token,
		"device_session_id": device_session_id,
		"access_expire_at_unix_sec": access_expire_at_unix_sec,
		"refresh_expire_at_unix_sec": refresh_expire_at_unix_sec,
		"session_state": session_state,
		"validation_bypassed": validation_bypassed,
	}


static func from_dict(data: Dictionary) -> AuthSessionState:
	var state := AuthSessionState.new()
	state.login_status = int(data.get("login_status", LoginStatus.LOGGED_OUT))
	state.account_id = String(data.get("account_id", ""))
	state.profile_id = String(data.get("profile_id", ""))
	state.display_name = String(data.get("display_name", ""))
	state.auth_mode = String(data.get("auth_mode", ""))
	state.access_token = String(data.get("access_token", ""))
	state.refresh_token = String(data.get("refresh_token", ""))
	state.device_session_id = String(data.get("device_session_id", ""))
	state.access_expire_at_unix_sec = int(data.get("access_expire_at_unix_sec", 0))
	state.refresh_expire_at_unix_sec = int(data.get("refresh_expire_at_unix_sec", 0))
	state.session_state = String(data.get("session_state", "logged_out"))
	state.validation_bypassed = bool(data.get("validation_bypassed", true))
	return state


func duplicate_deep() -> AuthSessionState:
	return AuthSessionState.from_dict(to_dict())
