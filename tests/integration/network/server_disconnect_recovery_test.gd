extends "res://tests/gut/base/qqt_integration_test.gd"

const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ServerRoomServiceScript = preload("res://network/session/runtime/server_room_service.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_main() -> void:
	var ok := _test_disconnect_abort_resets_room_and_marks_member_recoverable()


func _test_disconnect_abort_resets_room_and_marks_member_recoverable() -> bool:
	var room_service := ServerRoomServiceScript.new()
	var match_service := ServerMatchServiceScript.new()
	add_child(room_service)
	add_child(match_service)

	var match_messages: Array[Dictionary] = []
	var room_snapshots: Array[RoomSnapshot] = []
	var emitted_results: Array[BattleResult] = []

	match_service.broadcast_message.connect(func(message: Dictionary) -> void:
		match_messages.append(message.duplicate(true))
	)
	match_service.match_finished.connect(func(result: BattleResult) -> void:
		emitted_results.append(result.duplicate_deep())
	)
	room_service.room_snapshot_updated.connect(func(snapshot: RoomSnapshot) -> void:
		room_snapshots.append(snapshot.duplicate_deep())
	)

	_seed_room_state(room_service)
	var snapshot := room_service.room_state.build_snapshot()
	var start_result := match_service.start_match(snapshot)
	var prefix := "server_disconnect_recovery_test"
	var ok := true
	ok = qqt_check(bool(start_result.get("ok", false)), "server match should start from ready room snapshot", prefix) and ok
	ok = qqt_check(match_service.is_match_active(), "match should be active before disconnect abort", prefix) and ok

	var abort_result := match_service.abort_match_due_to_disconnect(3)
	room_service.handle_match_finished()
	room_service.handle_peer_disconnected(3)

	ok = qqt_check(abort_result != null, "disconnect abort should produce a battle result", prefix) and ok
	ok = qqt_check(not emitted_results.is_empty(), "disconnect abort should emit match_finished", prefix) and ok
	ok = qqt_check(not match_service.is_match_active(), "match should be inactive after disconnect abort", prefix) and ok
	if abort_result != null:
		ok = qqt_check(abort_result.finish_reason == "peer_disconnected", "disconnect abort should tag peer_disconnected finish reason", prefix) and ok
	if not emitted_results.is_empty():
		var emitted_result := emitted_results[0]
		ok = qqt_check(emitted_result.finish_reason == "peer_disconnected", "emitted battle result should preserve peer_disconnected finish reason", prefix) and ok

	var disconnect_message := _find_match_finished_message(match_messages)
	ok = qqt_check(not disconnect_message.is_empty(), "disconnect abort should broadcast MATCH_FINISHED", prefix) and ok
	if not disconnect_message.is_empty():
		ok = qqt_check(String(disconnect_message.get("message_type", "")) == TransportMessageTypesScript.MATCH_FINISHED, "broadcast message type should be MATCH_FINISHED", prefix) and ok
		ok = qqt_check(int(disconnect_message.get("disconnect_peer_id", 0)) == 3, "broadcast should identify disconnected peer", prefix) and ok

	ok = qqt_check(room_snapshots.size() >= 2, "room recovery should emit snapshots for ready reset and recoverable disconnect", prefix) and ok
	if room_snapshots.size() >= 2:
		var recovery_snapshot := room_snapshots[room_snapshots.size() - 2]
		var final_snapshot := room_snapshots[room_snapshots.size() - 1]
		ok = qqt_check(recovery_snapshot.members.size() == 2, "ready reset snapshot should keep both room members before removal", prefix) and ok
		ok = qqt_check(not recovery_snapshot.all_ready, "ready reset snapshot should no longer be startable", prefix) and ok
		ok = qqt_check(_member_ready(recovery_snapshot, 2) == false and _member_ready(recovery_snapshot, 3) == false, "ready reset snapshot should clear ready state for all members", prefix) and ok
		ok = qqt_check(final_snapshot.members.size() == 2, "final snapshot should keep recoverable disconnected peer", prefix) and ok
		ok = qqt_check(final_snapshot.owner_peer_id == 2, "final snapshot should keep remaining peer as owner", prefix) and ok
		var disconnected_member := _find_member(final_snapshot, 3)
		ok = qqt_check(disconnected_member != null, "final snapshot should include disconnected peer during resume window", prefix) and ok
		if disconnected_member != null:
			ok = qqt_check(disconnected_member.connection_state == "disconnected", "final snapshot should mark peer disconnected", prefix) and ok
		ok = qqt_check(_member_ready(final_snapshot, 2) == false, "remaining peer should stay unready after recovery", prefix) and ok

	if is_instance_valid(match_service):
		match_service.queue_free()
	if is_instance_valid(room_service):
		room_service.queue_free()
	return ok


func _seed_room_state(room_service: ServerRoomService) -> void:
	room_service.room_state.ensure_room("disconnect_recovery_room", 2)
	room_service.room_state.upsert_member(2, "Host", "hero_default")
	room_service.room_state.upsert_member(3, "Client", "hero_default")
	room_service.room_state.set_selection(
		MapCatalogScript.get_default_map_id(),
		RuleSetCatalogScript.get_default_rule_id(),
		ModeCatalogScript.get_default_mode_id()
	)
	room_service.room_state.set_ready(2, true)
	room_service.room_state.set_ready(3, true)


func _find_match_finished_message(messages: Array[Dictionary]) -> Dictionary:
	for message in messages:
		if String(message.get("message_type", message.get("msg_type", ""))) == TransportMessageTypesScript.MATCH_FINISHED:
			return message
	return {}


func _find_member(snapshot: RoomSnapshot, peer_id: int) -> RoomMemberState:
	for member in snapshot.members:
		if member.peer_id == peer_id:
			return member
	return null


func _member_ready(snapshot: RoomSnapshot, peer_id: int) -> bool:
	var member := _find_member(snapshot, peer_id)
	if member == null:
		return false
	return member.ready
