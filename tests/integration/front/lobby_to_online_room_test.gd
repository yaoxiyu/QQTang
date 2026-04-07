extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_lobby_can_build_online_create_and_join_entry_contexts()


func _test_lobby_can_build_online_create_and_join_entry_contexts() -> void:
	var runtime := AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var create_result: Dictionary = runtime.lobby_use_case.create_private_room("192.168.0.10", 9100)
	_assert_true(bool(create_result.get("ok", false)), "lobby can create online room entry context")
	var create_entry = create_result.get("entry_context", null)
	_assert_true(create_entry != null, "online create entry context exists")
	if create_entry != null:
		_assert_true(String(create_entry.entry_kind) == FrontEntryKindScript.ONLINE_CREATE, "online create uses ONLINE_CREATE kind")
		_assert_true(String(create_entry.room_kind) == FrontRoomKindScript.PRIVATE_ROOM, "online create uses private room kind")
		_assert_true(String(create_entry.topology) == FrontTopologyScript.DEDICATED_SERVER, "online create uses dedicated_server topology")
		_assert_true(String(create_entry.server_host) == "192.168.0.10", "online create keeps server host")
		_assert_true(int(create_entry.server_port) == 9100, "online create keeps server port")

	var join_result: Dictionary = runtime.lobby_use_case.join_private_room("", 0, "ROOM-1001")
	_assert_true(bool(join_result.get("ok", false)), "lobby can build online join entry context")
	var join_entry = join_result.get("entry_context", null)
	_assert_true(join_entry != null, "online join entry context exists")
	if join_entry != null:
		_assert_true(String(join_entry.entry_kind) == FrontEntryKindScript.ONLINE_JOIN, "online join uses ONLINE_JOIN kind")
		_assert_true(String(join_entry.target_room_id) == "ROOM-1001", "online join carries room id")
		_assert_true(String(join_entry.server_host) == "192.168.0.10", "online join reuses last server host when omitted")
		_assert_true(int(join_entry.server_port) == 9100, "online join reuses last server port when omitted")

	runtime.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
