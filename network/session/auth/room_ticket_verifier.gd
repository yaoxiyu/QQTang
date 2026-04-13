class_name RoomTicketVerifier
extends RefCounted

const RoomTicketClaimScript = preload("res://network/session/auth/room_ticket_claim.gd")
const RoomTicketValidationResultScript = preload("res://network/session/auth/room_ticket_validation_result.gd")

var secret: String = "dev_room_ticket_secret"
var allow_unsigned_dev_ticket: bool = false


func configure(next_secret: String, next_allow_unsigned_dev_ticket: bool = false) -> void:
	secret = next_secret if not next_secret.strip_edges().is_empty() else "dev_room_ticket_secret"
	allow_unsigned_dev_ticket = next_allow_unsigned_dev_ticket


func verify_create_ticket(message: Dictionary):
	var result = _verify_ticket(message)
	if not result.ok:
		return result
	var claim = result.claim
	if claim == null:
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket claim is missing")
	if claim.purpose != "create":
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_PURPOSE_INVALID", "Room ticket purpose is invalid")
	return result


func verify_join_ticket(message: Dictionary):
	var result = _verify_ticket(message)
	if not result.ok:
		return result
	var claim = result.claim
	if claim == null:
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket claim is missing")
	if claim.purpose != "join":
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_PURPOSE_INVALID", "Room ticket purpose is invalid")
	return result


func verify_resume_ticket(message: Dictionary):
	var result = _verify_ticket(message)
	if not result.ok:
		return result
	var claim = result.claim
	if claim == null:
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket claim is missing")
	if claim.purpose != "resume":
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_PURPOSE_INVALID", "Room ticket purpose is invalid")
	return result


func is_loadout_allowed(claim, character_id: String, character_skin_id: String, bubble_style_id: String, bubble_skin_id: String) -> bool:
	if claim == null:
		return false
	return _contains(claim.allowed_character_ids, character_id) \
		and _contains(claim.allowed_character_skin_ids, character_skin_id) \
		and _contains(claim.allowed_bubble_style_ids, bubble_style_id) \
		and _contains(claim.allowed_bubble_skin_ids, bubble_skin_id)


func resolve_requested_map_id(message: Dictionary, claim) -> String:
	if claim != null and not String(claim.locked_map_id).strip_edges().is_empty():
		return String(claim.locked_map_id).strip_edges()
	return String(message.get("map_id", "")).strip_edges()


func resolve_requested_rule_set_id(message: Dictionary, claim) -> String:
	if claim != null and not String(claim.locked_rule_set_id).strip_edges().is_empty():
		return String(claim.locked_rule_set_id).strip_edges()
	return String(message.get("rule_set_id", "")).strip_edges()


func resolve_requested_mode_id(message: Dictionary, claim) -> String:
	if claim != null and not String(claim.locked_mode_id).strip_edges().is_empty():
		return String(claim.locked_mode_id).strip_edges()
	return String(message.get("mode_id", "")).strip_edges()


func resolve_requested_team_id(message: Dictionary, claim) -> int:
	if claim != null and int(claim.assigned_team_id) > 0:
		return int(claim.assigned_team_id)
	return int(message.get("team_id", 0))


func _verify_ticket(message: Dictionary):
	var token := String(message.get("room_ticket", "")).strip_edges()
	if token.is_empty():
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_MISSING", "Room ticket is required")
	var parts := token.split(".")
	if parts.size() != 2:
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket format is invalid")
	var encoded_payload := String(parts[0])
	var provided_signature := String(parts[1])
	if encoded_payload.is_empty() or provided_signature.is_empty():
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket format is invalid")
	var expected_signature := _sign(encoded_payload)
	if expected_signature != provided_signature:
		if not allow_unsigned_dev_ticket:
			return RoomTicketValidationResultScript.fail("ROOM_TICKET_SIGNATURE_INVALID", "Room ticket signature is invalid")
	var payload_text := _decode_base64_url_to_text(encoded_payload)
	if payload_text.is_empty():
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket payload is invalid")
	var json := JSON.new()
	if json.parse(payload_text) != OK or not (json.data is Dictionary):
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket payload is invalid")
	var claim = RoomTicketClaimScript.from_dict(json.data)
	claim.signature = provided_signature
	var requested_ticket_id := String(message.get("room_ticket_id", "")).strip_edges()
	if not requested_ticket_id.is_empty() and claim.ticket_id != requested_ticket_id:
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_ID_MISMATCH", "Room ticket id is invalid")
	if claim.ticket_id.is_empty() or claim.account_id.is_empty() or claim.profile_id.is_empty() or claim.device_session_id.is_empty():
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_INVALID", "Room ticket claim is incomplete")
	var now_unix_sec := Time.get_unix_time_from_system()
	if int(claim.expire_at_unix_sec) <= now_unix_sec:
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_EXPIRED", "Room ticket has expired")
	if not _validate_target(message, claim):
		return RoomTicketValidationResultScript.fail("ROOM_TICKET_TARGET_INVALID", "Room ticket target is invalid")
	return RoomTicketValidationResultScript.success(claim)


func _validate_target(message: Dictionary, claim) -> bool:
	if claim == null:
		return false
	var requested_room_id := String(message.get("room_id", message.get("room_id_hint", ""))).strip_edges()
	var requested_room_kind := String(message.get("room_kind", "")).strip_edges().to_lower()
	var requested_match_id := String(message.get("match_id", "")).strip_edges()
	var claim_room_kind := String(claim.room_kind).strip_edges().to_lower()
	match claim.purpose:
		"create":
			if claim_room_kind == "matchmade_room":
				if requested_room_kind != "matchmade_room":
					return false
			elif not requested_room_kind.is_empty() and not claim_room_kind.is_empty() and requested_room_kind != claim_room_kind:
				return false
			return requested_room_id.is_empty() or claim.room_id.is_empty() or requested_room_id == claim.room_id
		"join":
			if claim_room_kind == "matchmade_room" and requested_room_kind != "matchmade_room":
				return false
			if requested_room_id.is_empty() or claim.room_id.is_empty():
				return false
			return requested_room_id == claim.room_id
		"resume":
			if requested_room_id.is_empty() or claim.room_id.is_empty() or requested_room_id != claim.room_id:
				return false
			if not requested_match_id.is_empty() and not claim.requested_match_id.is_empty() and requested_match_id != claim.requested_match_id:
				return false
			return true
		_:
			return false


func _sign(encoded_payload: String) -> String:
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, secret.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	return _to_base64_url(digest)


func _decode_base64_url_to_text(value: String) -> String:
	var normalized := value.replace("-", "+").replace("_", "/")
	while normalized.length() % 4 != 0:
		normalized += "="
	var bytes := Marshalls.base64_to_raw(normalized)
	return bytes.get_string_from_utf8()


func _to_base64_url(value: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(value).replace("+", "-").replace("/", "_").trim_suffix("=")


func _contains(values: Array[String], target: String) -> bool:
	for value in values:
		if value == target:
			return true
	return false
