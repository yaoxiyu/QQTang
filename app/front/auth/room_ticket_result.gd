class_name RoomTicketResult
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/auth/room_ticket_result.gd")

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var ticket: String = ""
var ticket_id: String = ""
var account_id: String = ""
var profile_id: String = ""
var device_session_id: String = ""
var purpose: String = ""
var room_id: String = ""
var room_kind: String = ""
var requested_match_id: String = ""
var display_name: String = ""
var allowed_character_ids: Array[String] = []
var allowed_character_skin_ids: Array[String] = []
var allowed_bubble_style_ids: Array[String] = []
var allowed_bubble_skin_ids: Array[String] = []
var issued_at_unix_sec: int = 0
var expire_at_unix_sec: int = 0


static func fail(p_error_code: String, p_user_message: String):
	var result = SELF_SCRIPT.new()
	result.ok = false
	result.error_code = p_error_code
	result.user_message = p_user_message
	return result


static func success_from_dict(data: Dictionary):
	var result = SELF_SCRIPT.new()
	result.ok = bool(data.get("ok", false))
	result.error_code = String(data.get("error_code", ""))
	result.user_message = String(data.get("user_message", data.get("message", "")))
	result.ticket = String(data.get("ticket", ""))
	result.ticket_id = String(data.get("ticket_id", ""))
	result.account_id = String(data.get("account_id", ""))
	result.profile_id = String(data.get("profile_id", ""))
	result.device_session_id = String(data.get("device_session_id", ""))
	result.purpose = String(data.get("purpose", ""))
	result.room_id = String(data.get("room_id", ""))
	result.room_kind = String(data.get("room_kind", ""))
	result.requested_match_id = String(data.get("requested_match_id", ""))
	result.display_name = String(data.get("display_name", ""))
	result.allowed_character_ids = _to_string_array(data.get("allowed_character_ids", []))
	result.allowed_character_skin_ids = _to_string_array(data.get("allowed_character_skin_ids", []))
	result.allowed_bubble_style_ids = _to_string_array(data.get("allowed_bubble_style_ids", []))
	result.allowed_bubble_skin_ids = _to_string_array(data.get("allowed_bubble_skin_ids", []))
	result.issued_at_unix_sec = int(data.get("issued_at_unix_sec", 0))
	result.expire_at_unix_sec = int(data.get("expire_at_unix_sec", 0))
	return result


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result
