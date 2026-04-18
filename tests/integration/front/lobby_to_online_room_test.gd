extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_online_room"
		result.ticket_id = "ticket_id_online_room"
		result.account_id = "account_online"
		result.profile_id = "profile_online"
		result.device_session_id = "dsess_online"
		return result


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	await _test_lobby_can_build_online_create_and_join_entry_contexts()


func _test_lobby_can_build_online_create_and_join_entry_contexts() -> void:
	var runtime := qqt_add_child(AppRuntimeRootScript.new())
	runtime.initialize_runtime()
	runtime.room_ticket_gateway = FakeRoomTicketGateway.new()
	runtime.auth_session_state.access_token = "access_online"
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

	var create_result: Dictionary = runtime.lobby_use_case.create_private_room("192.168.0.10", 9100)
	_assert_true(bool(create_result.get("ok", false)), "lobby can create online room entry context: %s" % JSON.stringify(create_result))
	var create_entry = create_result.get("entry_context", null)
	_assert_true(create_entry != null, "online create entry context exists")
	if create_entry != null:
		_assert_true(String(create_entry.entry_kind) == FrontEntryKindScript.ONLINE_CREATE, "online create uses ONLINE_CREATE kind")
		_assert_true(String(create_entry.room_kind) == FrontRoomKindScript.PRIVATE_ROOM, "online create uses private room kind")
		_assert_true(String(create_entry.topology) == FrontTopologyScript.DEDICATED_SERVER, "online create uses dedicated_server topology")
		_assert_true(String(create_entry.server_host) == "192.168.0.10", "online create keeps server host")
		_assert_true(int(create_entry.server_port) == 9100, "online create keeps server port")

	var join_result: Dictionary = runtime.lobby_use_case.join_private_room("", 0, "ROOM-1001")
	_assert_true(bool(join_result.get("ok", false)), "lobby can build online join entry context: %s" % JSON.stringify(join_result))
	var join_entry = join_result.get("entry_context", null)
	_assert_true(join_entry != null, "online join entry context exists")
	if join_entry != null:
		_assert_true(String(join_entry.entry_kind) == FrontEntryKindScript.ONLINE_JOIN, "online join uses ONLINE_JOIN kind")
		_assert_true(String(join_entry.target_room_id) == "ROOM-1001", "online join carries room id")
		_assert_true(String(join_entry.server_host) == "192.168.0.10", "online join reuses last server host when omitted")
		_assert_true(int(join_entry.server_port) == 9100, "online join reuses last server port when omitted")

	_free_current_scene(runtime)
	qqt_detach_and_free(runtime)


func _assert_true(condition: bool, message: String) -> void:
	assert_true(condition, message)


func _free_current_scene(runtime: Node = null) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	if runtime != null and not runtime.is_ancestor_of(tree.current_scene):
		return
	qqt_detach_and_free(tree.current_scene)
	tree.current_scene = null


