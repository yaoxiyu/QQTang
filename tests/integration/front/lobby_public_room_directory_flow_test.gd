extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomDirectoryEntryScript = preload("res://network/session/room/model/room_directory_entry.gd")
const RoomDirectorySnapshotScript = preload("res://network/session/room/model/room_directory_snapshot.gd")



func test_main() -> void:
	call_deferred("_main_body")


func _main_body() -> void:
	var ok := await _test_lobby_renders_public_room_directory_with_auto_connect()


func _test_lobby_renders_public_room_directory_with_auto_connect() -> bool:
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
	snapshot.server_port = 9100
	snapshot.entries = [_make_directory_entry()]
	runtime.client_room_runtime.room_directory_snapshot_received.emit(snapshot)

	var prefix := "lobby_public_room_directory_flow_test"
	var ok := true
	ok = qqt_check(runtime.client_room_runtime._connecting == true or runtime.client_room_runtime._directory_subscribed == true, "entering lobby should auto-connect directory transport", prefix) and ok
	ok = qqt_check(lobby_scene.public_room_list != null and lobby_scene.public_room_list.item_count == 1, "lobby should render one public room entry", prefix) and ok
	ok = qqt_check(lobby_scene._formal_room_grid != null and lobby_scene._formal_room_grid.get_child_count() == 8, "formal lobby should render eight room slots per page", prefix) and ok
	ok = qqt_check(
		String(lobby_scene.public_room_list.get_item_metadata(0)) == "ROOM-PUBLIC-1",
		"public room list metadata should keep room id",
		prefix
	) and ok
	ok = qqt_check(
		String(lobby_scene.directory_status_label.text).contains("Loaded 1 custom room"),
		"directory status should report loaded custom rooms",
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
	entry.mode_id = "box"
	entry.member_count = 2
	entry.max_players = 4
	entry.match_active = false
	entry.joinable = true
	return entry
