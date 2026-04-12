class_name RoomTicketValidationResult
extends RefCounted

const SELF_SCRIPT = preload("res://network/session/auth/room_ticket_validation_result.gd")

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var claim = null


static func fail(next_error_code: String, next_user_message: String):
	var result = SELF_SCRIPT.new()
	result.ok = false
	result.error_code = next_error_code
	result.user_message = next_user_message
	return result


static func success(next_claim):
	var result = SELF_SCRIPT.new()
	result.ok = true
	result.claim = next_claim
	return result
