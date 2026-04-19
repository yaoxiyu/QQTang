extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const FrontEntryKindScript = preload("res://app/front/navigation/front_entry_kind.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")



func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var ok := await _test_public_room_connect_timeout_reports_error()


func _test_public_room_connect_timeout_reports_error() -> bool:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	var entry_context := RoomEntryContextScript.new()
	entry_context.entry_kind = FrontEntryKindScript.ONLINE_JOIN
	entry_context.room_kind = FrontRoomKindScript.PUBLIC_ROOM
	entry_context.topology = FrontTopologyScript.DEDICATED_SERVER
	entry_context.server_host = "127.0.0.1"
	entry_context.server_port = 9100
	entry_context.target_room_id = "ROOM_TIMEOUT_TEST"
	var connection_config = runtime.room_use_case.build_room_connection_config(entry_context)
	assert_not_null(connection_config, "room use case should build connection config from entry context")
	if connection_config == null:
		return false
	connection_config.connect_timeout_sec = 0.5
	runtime.room_use_case._connection_orchestrator.begin_pending_connection(entry_context, connection_config)
	runtime.room_use_case._sync_pending_state_from_orchestrator()

	var captured_error := {"code": "", "message": ""}
	if not runtime.client_room_runtime.room_error.is_connected(_capture_room_error.bind(captured_error)):
		runtime.client_room_runtime.room_error.connect(_capture_room_error.bind(captured_error), CONNECT_ONE_SHOT)

	runtime.room_use_case._schedule_pending_connection_watchdog(connection_config)
	await get_tree().create_timer(2.0).timeout

	var prefix := "public_room_connect_timeout_reports_error_test"
	var ok := true
	ok = qqt_check(String(captured_error.get("code", "")) == "ROOM_CONNECT_TIMEOUT", "watchdog should emit room connect timeout error", prefix) and ok
	ok = qqt_check(String(captured_error.get("message", "")).contains("timed out"), "watchdog should expose timeout message", prefix) and ok
	ok = qqt_check(runtime.room_use_case._await_room_before_enter == false, "watchdog should clear pending room state", prefix) and ok
	ok = qqt_check(runtime.room_use_case._pending_connection_config == null, "watchdog should clear pending connection config", prefix) and ok
	ok = qqt_check(runtime.room_use_case._pending_online_entry_context == null, "watchdog should clear pending entry context", prefix) and ok

	if is_instance_valid(runtime):
		runtime.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return ok


func _capture_room_error(error_code: String, user_message: String, captured_error: Dictionary) -> void:
	captured_error["code"] = error_code
	captured_error["message"] = user_message



