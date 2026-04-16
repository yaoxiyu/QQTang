class_name RoomReturnRecovery
extends RefCounted

const ClientLaunchModeScript = preload("res://network/runtime/client_launch_mode.gd")


func recover(
	app_runtime: Node,
	post_action: String = "return_to_room"
) -> void:
	if app_runtime == null:
		return

	var room_controller = app_runtime.room_session_controller
	if room_controller != null and room_controller.has_method("begin_return_to_room"):
		room_controller.begin_return_to_room()
	var launch_mode := int(app_runtime.runtime_config.launch_mode) if app_runtime != null and app_runtime.runtime_config != null else ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER
	var is_network_client := launch_mode == ClientLaunchModeScript.Value.NETWORK_CLIENT
	var is_practice_room := false
	if room_controller != null and room_controller.get("room_session") != null and room_controller.room_session != null:
		is_practice_room = String(room_controller.room_session.room_kind) == "practice"
	if room_controller != null and is_network_client \
			and app_runtime.room_use_case != null \
			and app_runtime.room_use_case.room_gateway != null \
			and app_runtime.room_use_case.room_gateway.has_method("request_battle_return"):
		app_runtime.room_use_case.room_gateway.request_battle_return()
	if room_controller != null and not is_network_client:
		room_controller.reset_ready_state()
		if app_runtime.debug_tools != null and app_runtime.debug_tools.has_method("reset_local_loop_room_ready"):
			app_runtime.debug_tools.reset_local_loop_room_ready(
				room_controller,
				app_runtime.runtime_config,
				app_runtime.local_peer_id,
				app_runtime.remote_peer_id
			)
		if is_practice_room and room_controller.has_method("set_member_ready"):
			room_controller.set_member_ready(app_runtime.local_peer_id, true)

	if app_runtime.front_flow != null:
		match post_action:
			"return_to_room", "rematch":
				app_runtime.front_flow.return_to_room()
				app_runtime.front_flow.on_return_to_room_completed()
			_:
				pass

	if room_controller != null and room_controller.has_method("complete_return_to_room"):
		if app_runtime != null:
			app_runtime.current_room_snapshot = room_controller.build_room_snapshot().duplicate_deep()
		room_controller.complete_return_to_room()
