class_name RoomTicketClaim
extends RefCounted

const SELF_SCRIPT = preload("res://network/session/auth/room_ticket_claim.gd")

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
var nonce: String = ""
var signature: String = ""


func to_dict() -> Dictionary:
	return {
		"ticket_id": ticket_id,
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
		"purpose": purpose,
		"room_id": room_id,
		"room_kind": room_kind,
		"requested_match_id": requested_match_id,
		"display_name": display_name,
		"allowed_character_ids": allowed_character_ids.duplicate(),
		"allowed_character_skin_ids": allowed_character_skin_ids.duplicate(),
		"allowed_bubble_style_ids": allowed_bubble_style_ids.duplicate(),
		"allowed_bubble_skin_ids": allowed_bubble_skin_ids.duplicate(),
		"issued_at_unix_sec": issued_at_unix_sec,
		"expire_at_unix_sec": expire_at_unix_sec,
		"nonce": nonce,
		"signature": signature,
	}


static func from_dict(data: Dictionary):
	var claim = SELF_SCRIPT.new()
	claim.ticket_id = String(data.get("ticket_id", ""))
	claim.account_id = String(data.get("account_id", ""))
	claim.profile_id = String(data.get("profile_id", ""))
	claim.device_session_id = String(data.get("device_session_id", ""))
	claim.purpose = String(data.get("purpose", ""))
	claim.room_id = String(data.get("room_id", ""))
	claim.room_kind = String(data.get("room_kind", ""))
	claim.requested_match_id = String(data.get("requested_match_id", ""))
	claim.display_name = String(data.get("display_name", ""))
	claim.allowed_character_ids = _to_string_array(data.get("allowed_character_ids", []))
	claim.allowed_character_skin_ids = _to_string_array(data.get("allowed_character_skin_ids", []))
	claim.allowed_bubble_style_ids = _to_string_array(data.get("allowed_bubble_style_ids", []))
	claim.allowed_bubble_skin_ids = _to_string_array(data.get("allowed_bubble_skin_ids", []))
	claim.issued_at_unix_sec = int(data.get("issued_at_unix_sec", 0))
	claim.expire_at_unix_sec = int(data.get("expire_at_unix_sec", 0))
	claim.nonce = String(data.get("nonce", ""))
	claim.signature = String(data.get("signature", ""))
	return claim


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result
