extends Node

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ServerRoomRuntimeScript = preload("res://network/session/runtime/server_room_runtime.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


func _ready() -> void:
	var ok := true
	ok = _test_resume_window_timeout_triggers_match_finished_abort() and ok
	ok = _test_poll_expired_skips_unexpired_members() and ok
	if ok:
		print("active_match_resume_timeout_abort_test: PASS")


func _test_resume_window_timeout_triggers_match_finished_abort() -> bool:
	var fixture := _start_active_match()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var broadcasts: Array[Dictionary] = fixture["broadcasts"]
	var prefix := "active_match_resume_timeout_abort_test"
	var ok := true

	runtime.handle_peer_disconnected(3)
	var binding := runtime._room_service.room_state.get_member_binding_by_member_id(String(fixture["client_member_id"]))
	ok = TestAssert.is_true(binding != null, "disconnected client binding should remain available", prefix) and ok
	if binding != null:
		binding.disconnect_deadline_msec = 1

	runtime._resume_coordinator.poll_expired()

	var finish_message := _latest_match_finished(broadcasts)
	ok = TestAssert.is_true(not finish_message.is_empty(), "expired resume window should broadcast MATCH_FINISHED", prefix) and ok
	if not finish_message.is_empty():
		var result: Dictionary = finish_message.get("result", {})
		ok = TestAssert.is_true(String(result.get("finish_reason", "")) == "peer_resume_timeout", "finish reason should be peer_resume_timeout", prefix) and ok
		ok = TestAssert.is_true(String(finish_message.get("resume_timeout_member_id", "")) == String(fixture["client_member_id"]), "finished message should include timed out member id", prefix) and ok
	ok = TestAssert.is_true(not runtime.is_match_active(), "resume timeout should stop active match", prefix) and ok
	ok = TestAssert.is_true(not bool(runtime._room_service.room_state.match_active), "room state should leave active match after timeout", prefix) and ok

	runtime.free()
	return ok


func _test_poll_expired_skips_unexpired_members() -> bool:
	var fixture := _start_active_match()
	var runtime: ServerRoomRuntime = fixture["runtime"]
	var broadcasts: Array[Dictionary] = fixture["broadcasts"]
	var prefix := "active_match_resume_timeout_abort_test"
	var ok := true

	runtime.handle_peer_disconnected(3)
	var binding := runtime._room_service.room_state.get_member_binding_by_member_id(String(fixture["client_member_id"]))
	ok = TestAssert.is_true(binding != null, "disconnected client binding should remain available", prefix) and ok
	if binding != null:
		binding.disconnect_deadline_msec = Time.get_ticks_msec() + 20000

	runtime._resume_coordinator.poll_expired()

	ok = TestAssert.is_true(_latest_match_finished(broadcasts).is_empty(), "unexpired resume window should not finish match", prefix) and ok
	ok = TestAssert.is_true(runtime.is_match_active(), "unexpired resume window should keep match active", prefix) and ok

	runtime.free()
	return ok


func _start_active_match() -> Dictionary:
	var runtime := ServerRoomRuntimeScript.new()
	add_child(runtime)
	runtime.configure("127.0.0.1", 9000)

	var broadcasts: Array[Dictionary] = []
	runtime.broadcast_message.connect(func(message: Dictionary) -> void:
		broadcasts.append(message.duplicate(true))
	)
	runtime.send_to_peer.connect(func(_peer_id: int, message: Dictionary) -> void:
		broadcasts.append(message.duplicate(true))
	)

	runtime.create_room_from_request(_create_message(2))
	runtime.handle_room_message(_join_message(3))
	var client_binding = runtime._room_service.room_state.get_member_binding_by_transport_peer(3)
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 2})
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 3})
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_START_REQUEST, "sender_peer_id": 2})

	var loading_snapshot := _latest_loading_snapshot(broadcasts)
	runtime.handle_loading_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 2,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})
	runtime.handle_loading_message({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_READY,
		"sender_peer_id": 3,
		"match_id": String(loading_snapshot.get("match_id", "")),
		"revision": int(loading_snapshot.get("revision", 0)),
	})

	return {
		"runtime": runtime,
		"broadcasts": broadcasts,
		"client_member_id": client_binding.member_id if client_binding != null else "",
	}


func _create_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "create", "phase17_timeout_room", "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "phase17_timeout_room",
		"player_name": "Host",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"map_id": MapCatalogScript.get_default_map_id(),
		"rule_set_id": RuleSetCatalogScript.get_default_rule_id(),
		"mode_id": ModeCatalogScript.get_default_mode_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _join_message(peer_id: int) -> Dictionary:
	var ticket := _make_ticket(peer_id, "join", "phase17_timeout_room", "")
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "phase17_timeout_room",
		"player_name": "Client",
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _latest_loading_snapshot(broadcasts: Array[Dictionary]) -> Dictionary:
	for index in range(broadcasts.size() - 1, -1, -1):
		var message := broadcasts[index]
		if String(message.get("message_type", "")) == TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
			return Dictionary(message.get("snapshot", {}))
	return {}


func _latest_match_finished(broadcasts: Array[Dictionary]) -> Dictionary:
	for index in range(broadcasts.size() - 1, -1, -1):
		var message := broadcasts[index]
		if String(message.get("message_type", "")) == TransportMessageTypesScript.MATCH_FINISHED:
			return message
	return {}


func _make_ticket(peer_id: int, purpose: String, room_id: String, match_id: String) -> Dictionary:
	var payload := {
		"ticket_id": "ticket_%s_%d" % [purpose, peer_id],
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": purpose,
		"room_id": "" if purpose == "create" else room_id,
		"room_kind": "private_room" if purpose == "create" else "",
		"requested_match_id": match_id,
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_%s_%d" % [purpose, peer_id],
	}
	var encoded_payload := _to_base64_url(JSON.stringify(payload).to_utf8_buffer())
	var signature := _sign_ticket(encoded_payload)
	return {
		"token": "%s.%s" % [encoded_payload, signature],
		"ticket_id": String(payload.get("ticket_id", "")),
		"account_id": String(payload.get("account_id", "")),
		"profile_id": String(payload.get("profile_id", "")),
		"device_session_id": String(payload.get("device_session_id", "")),
	}


func _sign_ticket(encoded_payload: String) -> String:
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	return _to_base64_url(digest)


func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")
