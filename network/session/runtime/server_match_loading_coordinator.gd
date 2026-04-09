class_name ServerMatchLoadingCoordinator
extends RefCounted

const MatchLoadingSnapshotScript = preload("res://network/session/runtime/match_loading_snapshot.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

var current_snapshot: MatchLoadingSnapshot = null
var prepared_config: BattleStartConfig = null
var loading_active: bool = false
var expected_peer_ids: Array[int] = []
var ready_peer_ids: Array[int] = []
var current_revision: int = 0

var _prepare_match_callable: Callable
var _commit_match_callable: Callable
var _send_to_peer_callable: Callable
var _broadcast_message_callable: Callable
var _loading_started_callable: Callable
var _loading_aborted_callable: Callable
var _loading_committed_callable: Callable


func configure(
	prepare_match_callable: Callable,
	commit_match_callable: Callable,
	send_to_peer_callable: Callable,
	broadcast_message_callable: Callable,
	loading_started_callable: Callable = Callable(),
	loading_aborted_callable: Callable = Callable(),
	loading_committed_callable: Callable = Callable()
) -> void:
	_prepare_match_callable = prepare_match_callable
	_commit_match_callable = commit_match_callable
	_send_to_peer_callable = send_to_peer_callable
	_broadcast_message_callable = broadcast_message_callable
	_loading_started_callable = loading_started_callable
	_loading_aborted_callable = loading_aborted_callable
	_loading_committed_callable = loading_committed_callable


func begin_loading(room_snapshot) -> Dictionary:
	if loading_active:
		return {
			"ok": false,
			"error": "loading_already_active",
			"user_message": "A loading barrier is already in progress",
		}

	if not _prepare_match_callable.is_valid():
		return {
			"ok": false,
			"error": "prepare_match_callable_invalid",
			"user_message": "Server prepare match callable is not configured",
		}

	var prepare_result: Dictionary = _prepare_match_callable.call(room_snapshot)
	if not bool(prepare_result.get("ok", false)):
		return {
			"ok": false,
			"error": "prepare_match_failed",
			"validation": prepare_result.get("validation", {}),
			"user_message": String(prepare_result.get("validation", {}).get("error_message", "Failed to prepare match")),
		}

	prepared_config = prepare_result.get("config", null)
	if prepared_config == null:
		return {
			"ok": false,
			"error": "no_prepared_config",
			"user_message": "Server failed to generate battle config",
		}

	current_revision = prepared_config.server_match_revision
	expected_peer_ids = []
	ready_peer_ids = []
	for player_entry in prepared_config.player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id > 0:
			expected_peer_ids.append(peer_id)

	current_snapshot = MatchLoadingSnapshotScript.new()
	current_snapshot.room_id = room_snapshot.room_id
	current_snapshot.room_kind = room_snapshot.room_kind
	current_snapshot.room_display_name = room_snapshot.room_display_name
	current_snapshot.match_id = prepared_config.match_id
	current_snapshot.revision = current_revision
	current_snapshot.phase = "waiting"
	current_snapshot.owner_peer_id = room_snapshot.owner_peer_id
	current_snapshot.expected_peer_ids = expected_peer_ids.duplicate()
	current_snapshot.ready_peer_ids = []
	current_snapshot.waiting_peer_ids = expected_peer_ids.duplicate()
	current_snapshot.battle_seed = prepared_config.battle_seed

	loading_active = true
	if _loading_started_callable.is_valid():
		_loading_started_callable.call(current_snapshot.duplicate_deep())

	for peer_id in expected_peer_ids:
		var start_config_payload: Variant = {}
		if prepared_config is BattleStartConfig:
			var peer_config := prepared_config.duplicate_deep()
			peer_config.build_mode = BattleStartConfig.BUILD_MODE_CANDIDATE
			peer_config.session_mode = "network_client"
			peer_config.topology = "dedicated_server"
			peer_config.local_peer_id = peer_id
			peer_config.controlled_peer_id = peer_id
			start_config_payload = peer_config.to_dict()
		elif prepared_config != null and prepared_config.has_method("to_dict"):
			start_config_payload = prepared_config.to_dict()
		_send_to_peer_callable.call(peer_id, {
			"message_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED,
			"start_config": start_config_payload,
		})

	_broadcast_message_callable.call({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT,
		"snapshot": current_snapshot.to_dict(),
	})

	return {
		"ok": true,
		"snapshot": current_snapshot,
		"config": prepared_config,
	}


func mark_peer_ready(peer_id: int, match_id: String, revision: int) -> Dictionary:
	if not loading_active:
		return {
			"ok": false,
			"error": "loading_not_active",
			"user_message": "No loading barrier is currently active",
		}

	if match_id != current_snapshot.match_id:
		return {
			"ok": false,
			"error": "match_id_mismatch",
			"user_message": "Match ID does not match current loading session",
		}

	if revision != current_revision:
		return {
			"ok": false,
			"error": "revision_mismatch",
			"user_message": "Revision does not match current loading session",
		}

	if not expected_peer_ids.has(peer_id):
		return {
			"ok": false,
			"error": "peer_not_expected",
			"user_message": "Peer is not part of this loading session",
		}

	if ready_peer_ids.has(peer_id):
		return {
			"ok": true,
			"duplicate": true,
			"user_message": "Peer already marked as ready",
		}

	ready_peer_ids.append(peer_id)
	current_snapshot.ready_peer_ids = ready_peer_ids.duplicate()
	current_snapshot._recalculate_waiting_peers()

	_broadcast_message_callable.call({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT,
		"snapshot": current_snapshot.to_dict(),
	})

	if ready_peer_ids.size() == expected_peer_ids.size():
		return _try_commit_match()

	return {
		"ok": true,
		"committed": false,
		"ready_count": ready_peer_ids.size(),
		"expected_count": expected_peer_ids.size(),
	}


func abort_loading(error_code: String, user_message: String) -> void:
	if not loading_active:
		return

	loading_active = false
	current_snapshot.phase = "aborted"
	current_snapshot.error_code = error_code
	current_snapshot.user_message = user_message
	if _loading_aborted_callable.is_valid():
		_loading_aborted_callable.call(error_code, user_message, current_snapshot.duplicate_deep())

	_broadcast_message_callable.call({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT,
		"snapshot": current_snapshot.to_dict(),
	})

	reset()


func handle_peer_disconnected(peer_id: int) -> void:
	if not loading_active:
		return
	if expected_peer_ids.has(peer_id):
		abort_loading(
			"peer_disconnected_during_loading",
			"A player disconnected during loading. Match aborted."
		)


func is_loading_active() -> bool:
	return loading_active


func build_snapshot() -> MatchLoadingSnapshot:
	if current_snapshot == null:
		return null
	return current_snapshot.duplicate_deep()


func reset() -> void:
	loading_active = false
	current_snapshot = null
	prepared_config = null
	expected_peer_ids = []
	ready_peer_ids = []
	current_revision = 0


func _try_commit_match() -> Dictionary:
	if not _commit_match_callable.is_valid():
		abort_loading("commit_callable_invalid", "Server failed to commit match")
		return {
			"ok": false,
			"error": "commit_callable_invalid",
		}

	var commit_result: Dictionary = _commit_match_callable.call(prepared_config)
	if not bool(commit_result.get("ok", false)):
		abort_loading(
			"commit_failed",
			String(commit_result.get("user_message", "Server failed to commit match"))
		)
		return {
			"ok": false,
			"error": "commit_failed",
			"validation": commit_result.get("validation", {}),
		}

	loading_active = false
	current_snapshot.phase = "committed"
	if _loading_committed_callable.is_valid():
		var committed_config: Variant = prepared_config.duplicate_deep() if prepared_config is BattleStartConfig else prepared_config
		_loading_committed_callable.call(committed_config, current_snapshot.duplicate_deep())

	_broadcast_message_callable.call({
		"message_type": TransportMessageTypesScript.MATCH_LOADING_SNAPSHOT,
		"snapshot": current_snapshot.to_dict(),
	})

	return {
		"ok": true,
		"committed": true,
	}
