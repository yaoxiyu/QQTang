extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_ranked_match_room"
		result.ticket_id = "ticket_id_ranked_match_room"
		result.account_id = "account_ranked"
		result.profile_id = "profile_ranked"
		result.device_session_id = "dsess_ranked"
		return result


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.room_ticket_gateway = FakeRoomTicketGateway.new()
	runtime.auth_session_state.access_token = "access_ranked"
	runtime.player_profile_state.nickname = "RankedHost"
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

	var result: Dictionary = runtime.lobby_use_case.create_ranked_match_room("127.0.0.1", 9000)
	var entry = result.get("entry_context", null)
	var prefix := "lobby_create_ranked_match_room_test"
	var ok := true
	ok = TestAssert.is_true(bool(result.get("ok", false)), "ranked match room create should succeed", prefix) and ok
	ok = TestAssert.is_true(entry != null, "entry context should exist", prefix) and ok
	if entry != null:
		ok = TestAssert.is_true(String(entry.room_kind) == FrontRoomKindScript.RANKED_MATCH_ROOM, "room kind should be ranked match room", prefix) and ok
		ok = TestAssert.is_true(String(entry.queue_type) == "ranked", "queue type should be ranked", prefix) and ok
		ok = TestAssert.is_true(String(entry.match_format_id) == "1v1", "default match format should be 1v1", prefix) and ok
		ok = TestAssert.is_true(entry.selected_match_mode_ids.is_empty(), "match mode pool should start empty", prefix) and ok
	runtime.queue_free()
	if ok:
		print("lobby_create_ranked_match_room_test: PASS")
	test_finished.emit()
