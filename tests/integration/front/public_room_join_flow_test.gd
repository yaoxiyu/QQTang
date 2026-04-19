extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")



func test_main() -> void:
	call_deferred('_main_body')


func _main_body() -> void:
	var ok := await _test_public_room_create_and_join_keep_public_room_semantics()


func _test_public_room_create_and_join_keep_public_room_semantics() -> bool:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	runtime.front_flow.enter_lobby()

	var create_result: Dictionary = runtime.lobby_use_case.create_public_room("127.0.0.1", 9100, "Alpha Room")
	var create_entry = create_result.get("entry_context", null)
	var create_room_result: Dictionary = runtime.room_use_case.enter_room(create_entry)

	var join_result: Dictionary = runtime.lobby_use_case.join_public_room("", 0, "ROOM-PUB-88")
	var join_entry = join_result.get("entry_context", null)

	var prefix := "public_room_join_flow_test"
	var ok := true
	ok = qqt_check(bool(create_result.get("ok", false)), "create_public_room should succeed", prefix) and ok
	ok = qqt_check(String(create_entry.room_kind) == FrontRoomKindScript.PUBLIC_ROOM, "create entry should use public_room kind", prefix) and ok
	ok = qqt_check(String(create_entry.room_display_name) == "Alpha Room", "create entry should keep room display name", prefix) and ok
	ok = qqt_check(bool(create_room_result.get("pending", false)), "public room create should enter pending dedicated-server flow", prefix) and ok
	ok = qqt_check(
		runtime.room_use_case._pending_connection_config != null and String(runtime.room_use_case._pending_connection_config.room_display_name) == "Alpha Room",
		"pending connection config should preserve public room display name",
		prefix
	) and ok
	ok = qqt_check(bool(join_result.get("ok", false)), "join_public_room should succeed", prefix) and ok
	ok = qqt_check(String(join_entry.room_kind) == FrontRoomKindScript.PUBLIC_ROOM, "join entry should use public_room kind", prefix) and ok
	ok = qqt_check(String(join_entry.target_room_id) == "ROOM-PUB-88", "join entry should keep target room id", prefix) and ok
	ok = qqt_check(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.LOBBY), "public room flow should stay in lobby before authoritative snapshot arrives", prefix) and ok

	if is_instance_valid(runtime):
		runtime.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return ok



