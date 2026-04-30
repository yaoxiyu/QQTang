class_name LoadingUseCase
extends RefCounted

const LoadingViewStateScript = preload("res://app/front/loading/loading_view_state.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterTeamAnimationResolverScript = preload("res://content/character_animation_sets/runtime/character_team_animation_resolver.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")
const AsyncLoadingPlanScript = preload("res://app/front/loading/async_loading_plan.gd")
const LoadingProgressAggregatorScript = preload("res://app/front/loading/loading_progress_aggregator.gd")

var _app_runtime: Node = null
var _room_client_gateway: RefCounted = null
var _current_snapshot: MatchLoadingSnapshot = null
var _local_ready_submitted: bool = false
var _loading_mode: String = "normal_start"  # LegacyMigration

var _content_manifest_builder = BattleContentManifestBuilderScript.new()
var _loading_plan = null
var _progress_aggregator = LoadingProgressAggregatorScript.new()
var _room_connect_started_msec: int = 0


func configure(app_runtime: Node, room_client_gateway: RefCounted) -> void:
	_app_runtime = app_runtime
	_room_client_gateway = room_client_gateway


func begin_loading() -> Dictionary:
	_local_ready_submitted = false
	# LegacyMigration: Determine loading mode from app_runtime
	_loading_mode = "normal_start"
	if _app_runtime != null and "current_loading_mode" in _app_runtime:
		_loading_mode = String(_app_runtime.current_loading_mode)
	_build_loading_plan()
	
	# LegacyMigration: In resume mode, don't require snapshot
	if _loading_mode == "resume_match":
		_current_snapshot = null
		return {
			"ok": true,
			"resume_mode": true,
		}
	
	return {
		"ok": true,
	}


func begin_battle_entry_loading() -> Dictionary:
	_local_ready_submitted = false
	_loading_mode = "battle_entry"
	_build_loading_plan()
	return {
		"ok": true,
	}


func begin_room_connect_loading() -> Dictionary:
	_local_ready_submitted = false
	_current_snapshot = null
	_loading_mode = "room_connect"
	_room_connect_started_msec = Time.get_ticks_msec()
	_build_loading_plan()
	return {
		"ok": true,
	}


func prepare_battle_entry_resources_async(owner: Node, progress_callback: Callable = Callable()) -> Dictionary:
	var config: BattleStartConfig = _app_runtime.current_start_config if _app_runtime != null else null
	if config == null:
		_fail_loading_task("content_manifest", "START_CONFIG_MISSING", "Battle start config is missing")
		_call_progress(progress_callback)
		return {"ok": false, "error_code": "START_CONFIG_MISSING", "user_message": "Battle start config is missing"}

	_set_loading_task_progress("content_manifest", 0.15)
	_call_progress(progress_callback)
	await _yield_frame(owner)
	if _app_runtime.current_battle_content_manifest.is_empty():
		_app_runtime.current_battle_content_manifest = _content_manifest_builder.build_for_start_config(config)
		if _app_runtime.battle_context != null:
			_app_runtime.battle_context.current_battle_content_manifest = _app_runtime.current_battle_content_manifest.duplicate(true)
	_complete_loading_task("content_manifest")
	_call_progress(progress_callback)
	await _yield_frame(owner)

	_set_loading_task_progress("map_resources", 0.25)
	_call_progress(progress_callback)
	var map_layout := MapLoaderScript.load_runtime_layout(String(config.map_id))
	if map_layout == null:
		_fail_loading_task("map_resources", "MAP_RESOURCE_MISSING", "Map resource is missing: %s" % String(config.map_id))
		_call_progress(progress_callback)
		return {"ok": false, "error_code": "MAP_RESOURCE_MISSING", "user_message": "Map resource is missing"}
	_complete_loading_task("map_resources")
	_call_progress(progress_callback)
	await _yield_frame(owner)

	var character_units: int = maxi(config.character_loadouts.size(), 1)
	var loaded_units: int = 0
	for loadout in config.character_loadouts:
		var character_id := String(loadout.get("character_id", ""))
		var peer_id := int(loadout.get("peer_id", -1))
		var team_id := _resolve_team_id_for_peer(config, peer_id)
		var presentation := CharacterLoaderScript.load_character_presentation(character_id)
		if presentation == null:
			_fail_loading_task("character_resources", "CHARACTER_PRESENTATION_MISSING", "Character presentation is missing: %s" % character_id)
			_call_progress(progress_callback)
			return {"ok": false, "error_code": "CHARACTER_PRESENTATION_MISSING", "user_message": "Character presentation is missing"}
		var animation_set_id := CharacterTeamAnimationResolverScript.resolve_animation_set_id(String(presentation.animation_set_id), team_id, false)
		if CharacterAnimationSetLoaderScript.load_animation_set(animation_set_id) == null:
			_fail_loading_task("character_resources", "CHARACTER_ANIMATION_MISSING", "Character animation is missing: %s" % animation_set_id)
			_call_progress(progress_callback)
			return {"ok": false, "error_code": "CHARACTER_ANIMATION_MISSING", "user_message": "Character animation is missing"}
		loaded_units += 1
		_set_loading_task_progress("character_resources", float(loaded_units) / float(character_units))
		_call_progress(progress_callback)
		await _yield_frame(owner)

	for loadout in config.player_bubble_loadouts:
		var bubble_style_id := String(loadout.get("bubble_style_id", ""))
		if bubble_style_id.is_empty():
			continue
		BubbleLoaderScript.load_metadata(bubble_style_id)
		await _yield_frame(owner)
	_complete_loading_task("character_resources")
	_call_progress(progress_callback)
	return {"ok": true}


func consume_loading_snapshot(snapshot: MatchLoadingSnapshot) -> Dictionary:
	_current_snapshot = snapshot
	if snapshot.is_committed():
		return {
			"ok": true,
			"committed": true,
		}
	if snapshot.is_aborted():
		return {
			"ok": true,
			"aborted": true,
			"error_code": snapshot.error_code,
			"user_message": snapshot.user_message,
		}
	return {
		"ok": true,
		"waiting": true,
	}


func build_view_state() -> LoadingViewState:
	var state := LoadingViewStateScript.new()
	var config = _app_runtime.current_start_config if _app_runtime != null else null
	var manifest := _resolve_manifest(config)
	var ui_summary: Dictionary = manifest.get("ui_summary", {})

	state.map_display_name = String(ui_summary.get("map_display_name", config.map_id if config != null else ""))
	state.rule_display_name = String(ui_summary.get("rule_display_name", ""))
	state.mode_display_name = String(ui_summary.get("mode_display_name", ""))
	state.item_brief = String(ui_summary.get("item_brief", ""))
	state.character_brief = String(ui_summary.get("character_brief", ""))
	state.bubble_brief = String(ui_summary.get("bubble_brief", ""))
	
	# LegacyMigration: Set loading mode
	state.loading_mode = _loading_mode

	if _loading_mode == "room_connect":
		state.map_display_name = "Room"
		state.rule_display_name = ""
		state.mode_display_name = ""
		state.item_brief = ""
		state.character_brief = ""
		state.bubble_brief = ""
		state.loading_phase_text = _resolve_active_loading_task_id()
		state.waiting_summary_text = "Connecting"
		state.status_message = "Connecting to room..."
		_apply_progress_state(state)
		return state

	# LegacyMigration: Resume mode specific view state
	if _loading_mode == "resume_match":
		state.loading_phase_text = "resume_prepare"
		state.status_message = "Preparing resume payload..."
		state.resume_hint_text = "Rebinding to active dedicated-server match"
		if _app_runtime != null and "current_resume_snapshot" in _app_runtime and _app_runtime.current_resume_snapshot != null:
			state.resume_match_id = String(_app_runtime.current_resume_snapshot.match_id)
		var snapshot: RoomSnapshot = _app_runtime.current_room_snapshot if _app_runtime != null else null
		if snapshot != null:
			for member in snapshot.sorted_members():
				var line := _build_player_line(member)
				state.player_lines.append(line)
		return state

	var snapshot: RoomSnapshot = _app_runtime.current_room_snapshot if _app_runtime != null else null
	if snapshot != null:
		for member in snapshot.sorted_members():
			var line := _build_player_line(member)
			state.player_lines.append(line)

	if _current_snapshot != null:
		state.loading_phase_text = _current_snapshot.phase
		var ready_count := _current_snapshot.ready_peer_ids.size()
		var expected_count := _current_snapshot.expected_peer_ids.size()
		state.waiting_summary_text = "Ready: %d / %d" % [ready_count, expected_count]
		state.is_commit_ready = _current_snapshot.is_committed()

		if _current_snapshot.is_aborted():
			state.status_message = _current_snapshot.user_message
		elif _current_snapshot.is_committed():
			state.status_message = "All players ready. Entering battle..."
		else:
			state.status_message = "Waiting for players..."
	else:
		if _loading_mode == "battle_entry":
			state.loading_phase_text = _resolve_active_loading_task_id()
			state.status_message = "Preparing battle resources..."
		else:
			state.loading_phase_text = "initializing"
			state.status_message = "Missing BattleStartConfig. Preparing runtime..."

	_apply_progress_state(state)

	return state


func submit_local_ready() -> Dictionary:
	if _local_ready_submitted:
		return {
			"ok": true,
			"duplicate": true,
		}
	
	# LegacyMigration: In resume mode, skip loading ready submission
	if _loading_mode == "resume_match":
		return {
			"ok": true,
			"skipped": true,
		}

	if _current_snapshot == null:
		return {
			"ok": false,
			"error": "no_snapshot",
		}

	if _room_client_gateway == null or not _room_client_gateway.has_method("request_match_loading_ready"):
		return {
			"ok": false,
			"error": "gateway_not_available",
		}

	_room_client_gateway.request_match_loading_ready(
		_current_snapshot.match_id,
		_current_snapshot.revision
	)
	_local_ready_submitted = true
	return {
		"ok": true,
	}


func reset() -> void:
	_current_snapshot = null
	_local_ready_submitted = false
	_loading_plan = null


func _build_loading_plan() -> void:
	_loading_plan = AsyncLoadingPlanScript.create(_loading_mode)
	var ui_task = _loading_plan.add_task_values("ui_assets", "UI resources", 1.0)
	ui_task.complete()
	var manifest_task = _loading_plan.add_task_values("content_manifest", "Content manifest", 2.0)
	if _loading_mode != "battle_entry":
		manifest_task.set_progress(0.5)
	if _loading_mode == "battle_entry":
		_loading_plan.add_task_values("map_resources", "Map resources", 2.0)
		_loading_plan.add_task_values("character_resources", "Character resources", 4.0)
		_loading_plan.add_task_values("battle_ticket", "Battle ticket", 1.0)
		_loading_plan.add_task_values("room_ack", "Room acknowledgement", 1.0)
		return
	if _loading_mode == "room_connect":
		_loading_plan.add_task_values("transport", "Transport", 2.0)
		_loading_plan.add_task_values("room_request", "Room request", 1.0)
		_loading_plan.add_task_values("room_snapshot", "Room snapshot", 3.0)
		return
	var snapshot_task = _loading_plan.add_task_values("room_snapshot", "Room snapshot", 1.0)
	if _app_runtime != null and _app_runtime.current_room_snapshot != null:
		snapshot_task.complete()
	var ready_task = _loading_plan.add_task_values("network_ready", "Network ready", 2.0)
	if _loading_mode == "resume_match":
		ready_task.complete()


func _apply_progress_state(state: LoadingViewState) -> void:
	if _loading_plan == null:
		_build_loading_plan()
	if _loading_mode == "room_connect":
		_apply_room_connect_progress()
	var manifest_task = _loading_plan.find_task("content_manifest")
	if manifest_task != null and _loading_mode != "battle_entry":
		manifest_task.complete()
	var snapshot_task = _loading_plan.find_task("room_snapshot")
	if snapshot_task != null and _app_runtime != null and _app_runtime.current_room_snapshot != null:
		snapshot_task.complete()
	var ready_task = _loading_plan.find_task("network_ready")
	if ready_task != null:
		if state.is_commit_ready:
			ready_task.complete()
		elif _current_snapshot != null:
			var expected: int = max(_current_snapshot.expected_peer_ids.size(), 1)
			ready_task.set_progress(float(_current_snapshot.ready_peer_ids.size()) / float(expected))
	var result := _progress_aggregator.aggregate(_loading_plan)
	state.progress = float(result.get("progress", 0.0))
	state.progress_percent = int(result.get("progress_percent", 0))
	state.progress_detail_text = "%d%%" % state.progress_percent


func _apply_room_connect_progress() -> void:
	var transport_task = _loading_plan.find_task("transport") if _loading_plan != null else null
	var request_task = _loading_plan.find_task("room_request") if _loading_plan != null else null
	var snapshot_task = _loading_plan.find_task("room_snapshot") if _loading_plan != null else null
	if transport_task != null:
		if _app_runtime != null and _app_runtime.client_room_runtime != null and _app_runtime.client_room_runtime.has_method("is_transport_connected") and _app_runtime.client_room_runtime.is_transport_connected():
			transport_task.complete()
		else:
			var elapsed: int = maxi(Time.get_ticks_msec() - _room_connect_started_msec, 0)
			transport_task.set_progress(clampf(float(elapsed) / 1600.0, 0.05, 0.85))
	if request_task != null:
		if transport_task != null and int(transport_task.status) == AsyncLoadingTask.Status.COMPLETED:
			request_task.complete()
		else:
			request_task.set_progress(0.15)
	if snapshot_task != null:
		if _app_runtime != null and _app_runtime.current_room_snapshot != null:
			snapshot_task.complete()
		elif request_task != null and int(request_task.status) == AsyncLoadingTask.Status.COMPLETED:
			var snapshot_elapsed: int = maxi(Time.get_ticks_msec() - _room_connect_started_msec, 0)
			snapshot_task.set_progress(clampf(float(snapshot_elapsed) / 5000.0, 0.05, 0.70))


func _set_loading_task_progress(task_id: String, progress: float) -> void:
	if _loading_plan == null:
		_build_loading_plan()
	var task = _loading_plan.find_task(task_id)
	if task != null:
		task.set_progress(progress)


func _complete_loading_task(task_id: String) -> void:
	if _loading_plan == null:
		_build_loading_plan()
	var task = _loading_plan.find_task(task_id)
	if task != null:
		task.complete()


func _fail_loading_task(task_id: String, error_code: String, user_message: String) -> void:
	if _loading_plan == null:
		_build_loading_plan()
	var task = _loading_plan.find_task(task_id)
	if task != null:
		task.fail(error_code, user_message)


func mark_task_progress(task_id: String, progress: float) -> void:
	_set_loading_task_progress(task_id, progress)


func mark_task_complete(task_id: String) -> void:
	_complete_loading_task(task_id)


func mark_task_failed(task_id: String, error_code: String, user_message: String) -> void:
	_fail_loading_task(task_id, error_code, user_message)


func _resolve_team_id_for_peer(config: BattleStartConfig, peer_id: int) -> int:
	for slot in config.player_slots:
		if int(slot.get("peer_id", -1)) == peer_id:
			return int(slot.get("team_id", 0))
	return 0


func _call_progress(progress_callback: Callable) -> void:
	if progress_callback.is_valid():
		progress_callback.call()


func _yield_frame(owner: Node) -> void:
	if owner != null and owner.get_tree() != null:
		await owner.get_tree().process_frame


func _resolve_active_loading_task_id() -> String:
	if _loading_plan == null:
		return "initializing"
	for task in _loading_plan.tasks:
		if task == null:
			continue
		if int(task.status) == AsyncLoadingTask.Status.RUNNING or int(task.status) == AsyncLoadingTask.Status.PENDING:
			return String(task.task_id)
	return "ready"


func _resolve_manifest(config: BattleStartConfig) -> Dictionary:
	if _app_runtime != null and _app_runtime.has_method("get") and not _app_runtime.current_battle_content_manifest.is_empty():
		return _app_runtime.current_battle_content_manifest.duplicate(true)
	if config == null:
		return {}
	return _content_manifest_builder.build_for_start_config(config)


func _build_player_line(member: RoomMemberState) -> String:
	var loading_status := "waiting"
	if _current_snapshot != null:
		if _current_snapshot.ready_peer_ids.has(member.peer_id):
			loading_status = "ready"
		elif _current_snapshot.waiting_peer_ids.has(member.peer_id):
			loading_status = "waiting"
		elif _current_snapshot.is_committed():
			loading_status = "committed"
	return "%s | slot:%d | ready:%s | char:%s | bubble:%s" % [
		member.player_name,
		member.slot_index,
		loading_status,
		_resolve_character_display_name(member.character_id),
		_resolve_bubble_display_name(member.bubble_style_id),
	]


func _resolve_character_display_name(character_id: String) -> String:
	if character_id.is_empty():
		return "-"
	var entry := CharacterCatalogScript.get_character_entry(character_id)
	return String(entry.get("display_name", character_id))


func _resolve_bubble_display_name(bubble_style_id: String) -> String:
	if bubble_style_id.is_empty():
		return "-"
	var metadata := BubbleLoaderScript.load_metadata(bubble_style_id)
	return String(metadata.get("display_name", bubble_style_id))
