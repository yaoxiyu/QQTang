class_name BattleTicketVerifier
extends RefCounted

const RoomTicketClaimScript = preload("res://network/session/auth/room_ticket_claim.gd")

var secret: String = "dev_battle_ticket_secret"
var allow_unsigned_dev_ticket: bool = false


func configure(next_secret: String, next_allow_unsigned_dev_ticket: bool = false) -> void:
	secret = next_secret if not next_secret.strip_edges().is_empty() else "dev_battle_ticket_secret"
	allow_unsigned_dev_ticket = next_allow_unsigned_dev_ticket


func verify_entry_ticket(message: Dictionary, battle_id: String, manifest: Dictionary) -> Dictionary:
	var result := _verify_ticket(message)
	if not bool(result.get("ok", false)):
		return result
	var claim = result.get("claim", null)
	if claim == null:
		return _fail("BATTLE_TICKET_INVALID", "Battle ticket claim is missing")
	if String(claim.purpose) != "battle_entry":
		return _fail("BATTLE_TICKET_PURPOSE_INVALID", "Battle ticket purpose is invalid")
	if battle_id.strip_edges().is_empty():
		return _fail("BATTLE_ID_MISSING", "Battle id is required")
	var requested_battle_id := String(message.get("battle_id", "")).strip_edges()
	if not requested_battle_id.is_empty() and requested_battle_id != battle_id:
		return _fail("BATTLE_ID_MISMATCH", "Battle id does not match")
	if String(claim.assignment_id).strip_edges() != String(manifest.get("assignment_id", "")).strip_edges():
		return _fail("BATTLE_ASSIGNMENT_MISMATCH", "Battle assignment does not match")
	var manifest_match_id := String(manifest.get("match_id", "")).strip_edges()
	var requested_match_id := String(claim.requested_match_id).strip_edges()
	if not manifest_match_id.is_empty() and not requested_match_id.is_empty() and manifest_match_id != requested_match_id:
		return _fail("BATTLE_MATCH_MISMATCH", "Battle match id does not match")
	if not _validate_member(claim, manifest):
		return _fail("BATTLE_MEMBER_MISMATCH", "Battle member identity is invalid")
	if not _validate_locks(claim, manifest):
		return _fail("BATTLE_LOCK_MISMATCH", "Battle lock data is invalid")
	return result


func _verify_ticket(message: Dictionary) -> Dictionary:
	var token := String(message.get("battle_ticket", "")).strip_edges()
	if token.is_empty():
		return _fail("BATTLE_TICKET_MISSING", "Battle ticket is required")
	var parts := token.split(".")
	if parts.size() != 2:
		return _fail("BATTLE_TICKET_INVALID", "Battle ticket format is invalid")
	var encoded_payload := String(parts[0])
	var provided_signature := String(parts[1])
	if encoded_payload.is_empty() or provided_signature.is_empty():
		return _fail("BATTLE_TICKET_INVALID", "Battle ticket format is invalid")
	var expected_signature := _sign(encoded_payload)
	if expected_signature != provided_signature and not allow_unsigned_dev_ticket:
		return _fail("BATTLE_TICKET_SIGNATURE_INVALID", "Battle ticket signature is invalid")
	var payload_text := _decode_base64_url_to_text(encoded_payload)
	if payload_text.is_empty():
		return _fail("BATTLE_TICKET_INVALID", "Battle ticket payload is invalid")
	var json := JSON.new()
	if json.parse(payload_text) != OK or not (json.data is Dictionary):
		return _fail("BATTLE_TICKET_INVALID", "Battle ticket payload is invalid")
	var claim = RoomTicketClaimScript.from_dict(json.data)
	claim.signature = provided_signature
	var requested_ticket_id := String(message.get("battle_ticket_id", "")).strip_edges()
	if not requested_ticket_id.is_empty() and String(claim.ticket_id) != requested_ticket_id:
		return _fail("BATTLE_TICKET_ID_MISMATCH", "Battle ticket id is invalid")
	if String(claim.ticket_id).is_empty() or String(claim.account_id).is_empty() or String(claim.profile_id).is_empty() or String(claim.device_session_id).is_empty():
		return _fail("BATTLE_TICKET_INVALID", "Battle ticket claim is incomplete")
	var now_unix_sec := int(Time.get_unix_time_from_system())
	if int(claim.expire_at_unix_sec) <= now_unix_sec:
		return _fail("BATTLE_TICKET_EXPIRED", "Battle ticket has expired")
	return {
		"ok": true,
		"error_code": "",
		"user_message": "",
		"claim": claim,
	}


func _validate_member(claim, manifest: Dictionary) -> bool:
	var members: Array = manifest.get("members", [])
	for raw_member in members:
		var member: Dictionary = raw_member if raw_member is Dictionary else {}
		if String(member.get("account_id", "")) != String(claim.account_id):
			continue
		if String(member.get("profile_id", "")) != String(claim.profile_id):
			continue
		if int(claim.assigned_team_id) > 0 and int(member.get("assigned_team_id", 0)) != int(claim.assigned_team_id):
			return false
		return true
	return false


func _validate_locks(claim, manifest: Dictionary) -> bool:
	var manifest_map_id := String(manifest.get("map_id", "")).strip_edges()
	var manifest_rule_set_id := String(manifest.get("rule_set_id", "")).strip_edges()
	var manifest_mode_id := String(manifest.get("mode_id", "")).strip_edges()
	if not String(claim.locked_map_id).strip_edges().is_empty() and String(claim.locked_map_id).strip_edges() != manifest_map_id:
		return false
	if not String(claim.locked_rule_set_id).strip_edges().is_empty() and String(claim.locked_rule_set_id).strip_edges() != manifest_rule_set_id:
		return false
	if not String(claim.locked_mode_id).strip_edges().is_empty() and String(claim.locked_mode_id).strip_edges() != manifest_mode_id:
		return false
	var expected_member_count := int(manifest.get("expected_member_count", 0))
	if int(claim.expected_member_count) > 0 and expected_member_count > 0 and int(claim.expected_member_count) != expected_member_count:
		return false
	return true


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}


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
