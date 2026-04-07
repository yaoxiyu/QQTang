class_name AuthSessionState
extends RefCounted

enum LoginStatus {
	LOGGED_OUT = 0,
	LOGGED_IN = 1,
}

var login_status: int = LoginStatus.LOGGED_OUT
var account_id: String = ""
var display_name: String = ""
var auth_mode: String = ""
var access_token: String = ""
var refresh_token: String = ""
var validation_bypassed: bool = true


func clear() -> void:
	login_status = LoginStatus.LOGGED_OUT
	account_id = ""
	display_name = ""
	auth_mode = ""
	access_token = ""
	refresh_token = ""
	validation_bypassed = true
