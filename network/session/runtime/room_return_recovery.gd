class_name RoomReturnRecovery
extends RefCounted


func recover(
	app_runtime: Node,
	post_action: String = "return_to_room"
) -> void:
	if app_runtime == null:
		return

	var room_controller = app_runtime.room_session_controller
	if room_controller != null and room_controller.has_method("begin_return_to_room"):
		room_controller.begin_return_to_room()
	if room_controller != null:
		room_controller.reset_ready_state()
		if app_runtime.debug_tools != null and app_runtime.debug_tools.has_method("reset_local_loop_room_ready"):
			app_runtime.debug_tools.reset_local_loop_room_ready(
				room_controller,
				app_runtime.runtime_config,
				app_runtime.local_peer_id,
				app_runtime.remote_peer_id
			)

	if app_runtime.front_flow != null:
		match post_action:
			"return_to_room", "rematch":
				app_runtime.front_flow.return_to_room()
				app_runtime.front_flow.on_return_to_room_completed()
			_:
				pass

	if room_controller != null and room_controller.has_method("complete_return_to_room"):
		room_controller.complete_return_to_room()
