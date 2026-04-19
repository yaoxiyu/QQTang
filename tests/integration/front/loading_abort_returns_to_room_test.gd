extends "res://tests/gut/base/qqt_integration_test.gd"

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const LoadingSceneControllerScript = preload("res://scenes/front/loading_scene_controller.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")
const ServerRoomRuntimeScript = preload("res://network/session/runtime/server_room_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"


class MockRoomSessionController:
	extends RefCounted
	var last_error: Dictionary = {}

	func set_last_error(error_code: String, error_message: String, details: Dictionary = {}) -> void:
		last_error = {
			"error_code": error_code,
			"error_message": error_message,
			"details": details.duplicate(true),
		}


class MockAppRuntime:
	extends "res://tests/gut/base/qqt_integration_test.gd"
	var room_session_controller := MockRoomSessionController.new()


class MockFrontFlow:
	extends "res://tests/gut/base/qqt_integration_test.gd"
	var enter_room_calls: int = 0
	var match_loading_ready_calls: int = 0

	func enter_room() -> void:
		enter_room_calls += 1

	func on_match_loading_ready(_config = null) -> void:
		match_loading_ready_calls += 1


func test_main() -> void:
	var ok := true
	ok = _test_server_disconnect_before_commit_aborts_loading_and_reopens_room() and ok
	ok = _test_loading_scene_abort_returns_to_room_without_battle_transition() and ok


func _test_server_disconnect_before_commit_aborts_loading_and_reopens_room() -> bool:
	var runtime := ServerRoomRuntimeScript.new()
	var broadcasted := []
	add_child(runtime)
	runtime.configure("127.0.0.1", 9100)
	runtime.broadcast_message.connect(func(message): broadcasted.append(message))

	var mode_id := ModeCatalogScript.get_default_mode_id()
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var rule_id := String(mode_metadata.get("rule_set_id", RuleSetCatalogScript.get_default_rule_id()))
	var map_id := String(mode_metadata.get("default_map_id", MapCatalogScript.get_default_map_id()))

	runtime.create_room_from_request(_create_room_message(2, map_id, rule_id, mode_id))
	var room_id := runtime.get_room_id()
	runtime.handle_room_message(_join_room_message(3, room_id))
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 2})
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_TOGGLE_READY, "sender_peer_id": 3})
	runtime.handle_room_message({"message_type": TransportMessageTypesScript.ROOM_START_REQUEST, "sender_peer_id": 2})

	var prefix := "loading_abort_returns_to_room_test"
	var ok := true
	ok = qqt_check(runtime != null, "room runtime should exist before abort", prefix) and ok
	ok = qqt_check(
		runtime != null and runtime._room_service != null and bool(runtime._room_service.room_state.match_active),
		"room should be marked active while loading barrier is waiting",
		prefix
	) and ok

	runtime.handle_peer_disconnected(3)

	var aborted_snapshot := _find_loading_snapshot_with_phase(broadcasted, "aborted")
	var committed_snapshot := _find_loading_snapshot_with_phase(broadcasted, "committed")
	ok = qqt_check(not aborted_snapshot.is_empty(), "disconnect before commit should broadcast MATCH_LOADING_SNAPSHOT(aborted)", prefix) and ok
	ok = qqt_check(committed_snapshot.is_empty(), "disconnect before commit must not broadcast committed", prefix) and ok
	ok = qqt_check(
		runtime != null and runtime._room_service != null and not bool(runtime._room_service.room_state.match_active),
		"room should return to non-active state after loading abort",
		prefix
	) and ok

	runtime.queue_free()
	return ok


func _test_loading_scene_abort_returns_to_room_without_battle_transition() -> bool:
	var controller = LoadingSceneControllerScript.new()
	var app_runtime := MockAppRuntime.new()
	var front_flow := MockFrontFlow.new()

	controller._app_runtime = app_runtime
	controller._front_flow = front_flow

	var snapshot := MatchLoadingSnapshotScript.new()
	snapshot.phase = "aborted"
	snapshot.error_code = "peer_disconnected_during_loading"
	snapshot.user_message = "A player disconnected during loading. Match aborted."

	controller._handle_loading_aborted(snapshot)

	var prefix := "loading_abort_returns_to_room_test"
	var ok := true
	ok = qqt_check(front_flow.enter_room_calls == 1, "loading abort should return to room", prefix) and ok
	ok = qqt_check(front_flow.match_loading_ready_calls == 0, "loading abort must not enter battle", prefix) and ok
	ok = qqt_check(
		app_runtime.room_session_controller.last_error.get("error_code", "") == "peer_disconnected_during_loading",
		"loading abort should expose room error",
		prefix
	) and ok

	controller.free()
	app_runtime.free()
	front_flow.free()
	return ok


func _find_loading_snapshot_with_phase(messages: Array, phase: String) -> Dictionary:
	for message in messages:
		if String(message.get("message_type", message.get("msg_type", ""))) != TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT:
			continue
		var snapshot: Dictionary = message.get("snapshot", {})
		if String(snapshot.get("phase", "")) == phase:
			return snapshot
	return {}


func _create_room_message(peer_id: int, map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	var ticket := _make_room_ticket({
		"ticket_id": "ticket_create_%d" % peer_id,
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": "create",
		"room_id": "",
		"room_kind": "private_room",
		"requested_match_id": "",
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_create_%d" % peer_id,
	})
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "",
		"room_kind": "private_room",
		"room_display_name": "",
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"map_id": map_id,
		"rule_set_id": rule_id,
		"mode_id": mode_id,
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _join_room_message(peer_id: int, room_id: String) -> Dictionary:
	var ticket := _make_room_ticket({
		"ticket_id": "ticket_join_%d" % peer_id,
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": "join",
		"room_id": room_id,
		"room_kind": "",
		"requested_match_id": "",
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_join_%d" % peer_id,
	})
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _make_room_ticket(payload: Dictionary) -> Dictionary:
	var json := JSON.stringify(payload)
	var encoded_payload := Marshalls.raw_to_base64(json.to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=")
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	var signature := Marshalls.raw_to_base64(digest).replace("+", "-").replace("/", "_").trim_suffix("=")
	var token := "%s.%s" % [encoded_payload, signature]
	var result := payload.duplicate(true)
	result["token"] = token
	return result


