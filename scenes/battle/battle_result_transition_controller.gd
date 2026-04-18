extends RefCounted


func resolve_current_match_id(app_runtime: Node) -> String:
	if app_runtime != null and app_runtime.current_start_config != null:
		return String(app_runtime.current_start_config.match_id)
	return ""


func should_return_to_lobby_after_settlement(app_runtime: Node) -> bool:
	if app_runtime == null:
		return false
	if app_runtime.current_room_entry_context != null and bool(app_runtime.current_room_entry_context.return_to_lobby_after_settlement):
		return true
	if app_runtime.current_room_entry_context != null and String(app_runtime.current_room_entry_context.room_kind) == "matchmade_room":
		return true
	if app_runtime.current_room_snapshot != null and String(app_runtime.current_room_snapshot.room_kind) == "matchmade_room":
		return true
	return false


func clear_runtime_settlement_summary(app_runtime: Node, settlement_sync_token: int, log_online_flow: Callable) -> int:
	if app_runtime == null:
		return settlement_sync_token
	app_runtime.current_settlement_popup_summary = {}
	var next_token := settlement_sync_token + 1
	if log_online_flow.is_valid():
		log_online_flow.call("settlement_summary_cleared", {
			"match_id": resolve_current_match_id(app_runtime),
			"settlement_sync_token": next_token,
		})
	return next_token


func on_battle_finished_authoritatively(
	app_runtime: Node,
	result: BattleResult,
	settlement_sync_token: int,
	settlement_show_delay_sec: float,
	log_online_flow: Callable
) -> Dictionary:
	if app_runtime != null and app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("mark_match_finished"):
		var match_id: String = app_runtime.current_start_config.match_id if app_runtime.current_start_config != null else ""
		app_runtime.room_session_controller.mark_match_finished(match_id)
	settlement_sync_token = clear_runtime_settlement_summary(app_runtime, settlement_sync_token, log_online_flow)
	var match_id := resolve_current_match_id(app_runtime)
	if log_online_flow.is_valid():
		log_online_flow.call("battle_finished_authoritatively", {
			"match_id": match_id,
			"finish_reason": result.finish_reason if result != null else "",
			"local_outcome": result.local_outcome if result != null else "",
			"return_to_lobby_after_settlement": should_return_to_lobby_after_settlement(app_runtime),
		})
	return {
		"pending_settlement_result": result.duplicate_deep() if result != null else null,
		"settlement_delay_remaining": settlement_show_delay_sec,
		"settlement_sync_token": settlement_sync_token,
		"match_id": match_id,
	}


func show_pending_settlement(
	app_runtime: Node,
	settlement_controller: Node,
	battle_hud: Node,
	pending_settlement_result: BattleResult,
	log_online_flow: Callable
) -> void:
	if pending_settlement_result == null:
		return
	if app_runtime != null and app_runtime.front_flow != null:
		app_runtime.front_flow.on_battle_finished(pending_settlement_result)
	if should_return_to_lobby_after_settlement(app_runtime):
		settlement_controller.set_return_button_mode_lobby()
	else:
		settlement_controller.set_return_button_mode_room()
	settlement_controller.show_result(pending_settlement_result)
	if log_online_flow.is_valid():
		log_online_flow.call("settlement_opened", {
			"match_id": resolve_current_match_id(app_runtime),
			"return_mode": "lobby" if should_return_to_lobby_after_settlement(app_runtime) else "room",
			"has_cached_server_summary": app_runtime != null and not app_runtime.current_settlement_popup_summary.is_empty(),
		})
	if app_runtime != null:
		var popup_summary: Dictionary = app_runtime.current_settlement_popup_summary.duplicate(true)
		if not popup_summary.is_empty():
			settlement_controller.apply_server_summary(popup_summary)
	if should_return_to_lobby_after_settlement(app_runtime):
		battle_hud.match_message_panel.apply_message("Press Enter to return lobby")
	else:
		battle_hud.match_message_panel.apply_message("Press Enter to return room")


func request_post_shutdown_action(
	action: String,
	app_runtime: Node,
	current_post_shutdown_action: String,
	log_online_flow: Callable
) -> String:
	if not current_post_shutdown_action.is_empty():
		return current_post_shutdown_action
	if action == "rematch" and app_runtime != null:
		var entry_context = app_runtime.current_room_entry_context
		if entry_context != null and String(entry_context.topology) == "dedicated_server":
			app_runtime.pending_room_action = "rematch"
			if app_runtime.room_session_controller != null and app_runtime.room_session_controller.has_method("set_pending_room_action"):
				app_runtime.room_session_controller.set_pending_room_action("rematch")
	if log_online_flow.is_valid():
		log_online_flow.call("post_shutdown_action_requested", {
			"action": action,
			"match_id": resolve_current_match_id(app_runtime),
		})
	return action


func complete_post_shutdown_action(
	post_shutdown_action: String,
	app_runtime: Node,
	room_return_recovery,
	queue_scene_cleanup: Callable
) -> void:
	match post_shutdown_action:
		"return_to_room", "rematch":
			if app_runtime != null:
				room_return_recovery.recover(app_runtime, post_shutdown_action)
		"return_to_lobby":
			if app_runtime != null and app_runtime.room_use_case != null and app_runtime.room_use_case.has_method("leave_room"):
				app_runtime.room_use_case.leave_room()
			elif app_runtime != null and app_runtime.front_flow != null and app_runtime.front_flow.has_method("enter_lobby"):
				app_runtime.front_flow.enter_lobby()
		_:
			pass
	if queue_scene_cleanup.is_valid():
		queue_scene_cleanup.call()


func fetch_server_settlement_summary_with_retry(
	owner: Node,
	app_runtime: Node,
	settlement_controller: Node,
	match_id: String,
	token: int,
	settlement_sync_token_resolver: Callable,
	log_online_flow: Callable,
	retry_delays_sec: Array[float]
) -> void:
	for attempt in range(retry_delays_sec.size() + 1):
		if settlement_sync_token_resolver.is_valid() and token != int(settlement_sync_token_resolver.call()):
			return
		var synced := _fetch_server_settlement_summary_once(app_runtime, settlement_controller, match_id, log_online_flow)
		if synced:
			return
		if attempt >= retry_delays_sec.size():
			return
		await owner.get_tree().create_timer(float(retry_delays_sec[attempt])).timeout


func _fetch_server_settlement_summary_once(
	app_runtime: Node,
	settlement_controller: Node,
	match_id: String,
	log_online_flow: Callable
) -> bool:
	if match_id.strip_edges().is_empty() or app_runtime == null:
		return true
	if app_runtime.settlement_sync_use_case == null or not app_runtime.settlement_sync_use_case.has_method("fetch_match_summary"):
		return true
	if log_online_flow.is_valid():
		log_online_flow.call("settlement_summary_fetch_requested", {
			"match_id": match_id,
		})
	var fetch_result: Dictionary = app_runtime.settlement_sync_use_case.fetch_match_summary(match_id)
	if not bool(fetch_result.get("ok", false)):
		if log_online_flow.is_valid():
			log_online_flow.call("settlement_summary_fetch_failed", {
				"match_id": match_id,
				"error_code": String(fetch_result.get("error_code", "")),
				"user_message": String(fetch_result.get("user_message", "")),
			})
		return false
	var popup_result: Dictionary = app_runtime.settlement_sync_use_case.apply_summary_to_popup(fetch_result.get("summary", null))
	if not bool(popup_result.get("ok", false)):
		if log_online_flow.is_valid():
			log_online_flow.call("settlement_popup_apply_failed", {
				"match_id": match_id,
				"error_code": String(popup_result.get("error_code", "")),
				"user_message": String(popup_result.get("user_message", "")),
			})
		return false
	var popup_summary: Dictionary = popup_result.get("popup_summary", {})
	app_runtime.current_settlement_popup_summary = popup_summary.duplicate(true)
	if settlement_controller != null and settlement_controller.visible:
		settlement_controller.apply_server_summary(popup_summary)
	var synced := String(popup_summary.get("server_sync_state", "")).strip_edges().to_lower() != "pending"
	if log_online_flow.is_valid():
		log_online_flow.call("settlement_summary_fetch_succeeded", {
			"match_id": match_id,
			"server_sync_state": String(popup_summary.get("server_sync_state", "")),
			"rating_delta": int(popup_summary.get("rating_delta", 0)),
			"season_point_delta": int(popup_summary.get("season_point_delta", 0)),
			"synced": synced,
		})
	return synced
