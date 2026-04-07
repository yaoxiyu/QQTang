class_name LoginResult
extends RefCounted

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var account_id: String = ""
var display_name: String = ""
var auth_mode: String = ""
var validation_bypassed: bool = true


static func success(
	p_account_id: String,
	p_display_name: String,
	p_auth_mode: String,
	p_validation_bypassed: bool = true,
	p_user_message: String = ""
) -> LoginResult:
	var result := LoginResult.new()
	result.ok = true
	result.account_id = p_account_id
	result.display_name = p_display_name
	result.auth_mode = p_auth_mode
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
