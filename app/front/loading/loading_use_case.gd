class_name LoadingUseCase
extends RefCounted

const LoadingViewStateScript = preload("res://app/front/loading/loading_view_state.gd")
const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")

var _app_runtime: Node = null
var _room_client_gateway: RefCounted = null
var _current_snapshot: MatchLoadingSnapshot = null
var _local_ready_submitted: bool = false
var _loading_mode: String = "normal_start"  # Phase17

var _content_manifest_builder = BattleContentManifestBuilderScript.new()


func configure(app_runtime: Node, room_client_gateway: RefCounted) -> void:
	_app_runtime = app_runtime
	_room_client_gateway = room_client_gateway


func begin_loading() -> Dictionary:
	_local_ready_submitted = false
	# Phase17: Determine loading mode from app_runtime
	_loading_mode = "normal_start"
	if _app_runtime != null and "current_loading_mode" in _app_runtime:
		_loading_mode = String(_app_runtime.current_loading_mode)
	
	# Phase17: In resume mode, don't require snapshot
	if _loading_mode == "resume_match":
		_current_snapshot = null
		return {
			"ok": true,
			"resume_mode": true,
		}
	
	return {
		"ok": true,
	}


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
	
	# Phase17: Set loading mode
	state.loading_mode = _loading_mode

	# Phase17: Resume mode specific view state
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
		state.loading_phase_text = "initializing"
		state.status_message = "Missing BattleStartConfig. Preparing runtime..."

	return state


func submit_local_ready() -> Dictionary:
	if _local_ready_submitted:
		return {
			"ok": true,
			"duplicate": true,
		}
	
	# Phase17: In resume mode, skip loading ready submission
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
	var metadata := CharacterLoaderScript.load_character_metadata(character_id)
	return String(metadata.get("display_name", character_id))


func _resolve_bubble_display_name(bubble_style_id: String) -> String:
	if bubble_style_id.is_empty():
		return "-"
	var metadata := BubbleLoaderScript.load_metadata(bubble_style_id)
	return String(metadata.get("display_name", bubble_style_id))
