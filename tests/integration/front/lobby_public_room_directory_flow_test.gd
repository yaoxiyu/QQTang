extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomDirectoryEntryScript = preload("res://network/session/runtime/room_directory_entry.gd")
const RoomDirectorySnapshotScript = preload("res://network/session/runtime/room_directory_snapshot.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var ok := await _test_lobby_renders_public_room_directory_without_auto_connect()
	if ok:
		print("lobby_public_room_directory_flow_test: PASS")
	test_finished.emit()


func _test_lobby_renders_public_room_directory_without_auto_connect() -> bool:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	runtime.front_flow.enter_lobby()

	var lobby_scene: Node = load("res://scenes/front/lobby_scene.tscn").instantiate()
	add_child(lobby_scene)
	await get_tree().process_frame

	var snapshot := RoomDirectorySnapshotScript.new()
	snapshot.revision = 1
	snapshot.server_host = "127.0.0.1"
	snapshot.server_port = 9000
	snapshot.entries = [_make_directory_entry()]
	runtime.client_room_runtime.room_directory_snapshot_received.emit(snapshot)

	var prefix := "lobby_public_room_directory_flow_test"
	var ok := true
	ok = TestAssert.is_true(runtime.client_room_runtime._connecting == false, "entering lobby should not auto-connect directory transport", prefix) and ok
	ok = TestAssert.is_true(runtime.client_room_runtime._directory_subscribed == false, "entering lobby should not auto-subscribe directory", prefix) and ok
	ok = TestAssert.is_true(lobby_scene.public_room_list != null and lobby_scene.public_room_list.item_count == 1, "lobby should render one public room entry", prefix) and ok
	ok = TestAssert.is_true(
		String(lobby_scene.public_room_list.get_item_metadata(0)) == "ROOM-PUBLIC-1",
		"public room list metadata should keep room id",
		prefix
	) and ok
	ok = TestAssert.is_true(
		String(lobby_scene.directory_status_label.text).contains("Loaded 1 public room"),
		"directory status should report loaded public rooms",
		prefix
	) and ok

	if is_instance_valid(lobby_scene):
		lobby_scene.queue_free()
	if is_instance_valid(runtime):
		runtime.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return ok


func _make_directory_entry():
	var entry := RoomDirectoryEntryScript.new()
	entry.room_id = "ROOM-PUBLIC-1"
	entry.room_display_name = "Alpha Lobby"
	entry.room_kind = "public_room"
	entry.owner_peer_id = 1
	entry.owner_name = "Host"
	entry.selected_map_id = "map_alpha"
	entry.rule_set_id = "ruleset_classic"
	entry.mode_id = "mode_classic"
	entry.member_count = 2
	entry.max_players = 4
	entry.match_active = false
	entry.joinable = true
	return entry
