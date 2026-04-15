extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_casual_match_room"
		result.ticket_id = "ticket_id_casual_match_room"
		result.account_id = "account_casual"
		result.profile_id = "profile_casual"
		result.device_session_id = "dsess_casual"
		return result


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var runtime : Node = _build_runtime()
	var result: Dictionary = runtime.lobby_use_case.create_casual_match_room("127.0.0.1", 9000)
	var entry = result.get("entry_context", null)
	var prefix := "lobby_create_casual_match_room_test"
	var ok := true
	ok = TestAssert.is_true(runtime.matchmaking_use_case == null, "formal runtime should not create legacy matchmaking use case", prefix) and ok
	ok = TestAssert.is_true(bool(result.get("ok", false)), "casual match room create should succeed", prefix) and ok
	ok = TestAssert.is_true(entry != null, "entry context should exist", prefix) and ok
	if entry != null:
		ok = TestAssert.is_true(String(entry.entry_kind) == FrontEntryKindScript.ONLINE_CREATE, "casual match room should use online create", prefix) and ok
		ok = TestAssert.is_true(String(entry.room_kind) == FrontRoomKindScript.CASUAL_MATCH_ROOM, "room kind should be casual match room", prefix) and ok
		ok = TestAssert.is_true(String(entry.topology) == FrontTopologyScript.DEDICATED_SERVER, "match room should use dedicated server", prefix) and ok
		ok = TestAssert.is_true(String(entry.queue_type) == "casual", "queue type should be casual", prefix) and ok
		ok = TestAssert.is_true(String(entry.match_format_id) == "1v1", "default match format should be 1v1", prefix) and ok
		ok = TestAssert.is_true(bool(entry.is_prequeue_match_room), "entry should be marked as prequeue match room", prefix) and ok
	runtime.queue_free()
	if ok:
		print("lobby_create_casual_match_room_test: PASS")
	test_finished.emit()


func _build_runtime():
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.room_ticket_gateway = FakeRoomTicketGateway.new()
	runtime.auth_session_state.access_token = "access_casual"
	runtime.player_profile_state.nickname = "CasualHost"
	runtime.lobby_use_case.configure(
		runtime,
		runtime.auth_session_state,
		runtime.player_profile_state,
		runtime.front_settings_state,
		runtime.practice_room_factory,
		runtime.auth_session_repository,
		runtime.logout_use_case,
		runtime.profile_gateway,
		runtime.room_ticket_gateway
	)
	return runtime
