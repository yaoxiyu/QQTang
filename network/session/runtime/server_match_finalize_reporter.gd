class_name ServerMatchFinalizeReporter
extends RefCounted

const FINALIZE_PATH := "/internal/v1/matches/finalize"
const ASSIGNMENT_COMMIT_PATH_TEMPLATE := "/internal/v1/assignments/%s/commit"

var game_service_host: String = "127.0.0.1"
var game_service_port: int = 18081
var internal_shared_secret: String = ""
var last_finalize_status: Dictionary = {}
var last_assignment_commit_status: Dictionary = {}
var retry_delays_msec: Array[int] = [500, 1500, 3000]


func configure(
	p_game_service_host: String = "",
	p_game_service_port: int = 0,
	p_internal_shared_secret: String = ""
) -> void:
	game_service_host = p_game_service_host.strip_edges() if not p_game_service_host.strip_edges().is_empty() else _read_env("GAME_SERVICE_HOST", "127.0.0.1")
	game_service_port = p_game_service_port if p_game_service_port > 0 else int(_read_env("GAME_SERVICE_PORT", "18081").to_int())
	if game_service_port <= 0:
		game_service_port = 18081
	internal_shared_secret = p_internal_shared_secret if not p_internal_shared_secret.strip_edges().is_empty() else _read_env("GAME_INTERNAL_SHARED_SECRET", "")


func report_match_result_async(room_runtime: Node, result: BattleResult) -> void:
	var duplicated_result := result.duplicate_deep() if result != null else null
	call_deferred("_report_match_result", room_runtime, duplicated_result)


func report_assignment_commit_async(payload: Dictionary) -> void:
	call_deferred("_report_assignment_commit", payload.duplicate(true))


func _report_match_result(room_runtime: Node, result: BattleResult) -> void:
	var payload := _build_finalize_payload(room_runtime, result)
	if payload.is_empty():
		last_finalize_status = {
			"ok": false,
			"error_code": "MATCH_FINALIZE_PAYLOAD_INVALID",
			"user_message": "Finalize payload is incomplete",
			"reported_at": _utc_now_string(),
		}
		return
	var result_hash := _build_result_hash(payload)
	payload["result_hash"] = result_hash
	var response := await _send_internal_post_with_retry(FINALIZE_PATH, payload)
	response["result_hash"] = result_hash
	response["reported_at"] = _utc_now_string()
	last_finalize_status = response


func _report_assignment_commit(payload: Dictionary) -> void:
	var assignment_id := String(payload.get("assignment_id", "")).strip_edges()
	if assignment_id.is_empty():
		last_assignment_commit_status = {
			"ok": false,
			"error_code": "MATCHMAKING_ASSIGNMENT_ID_MISSING",
			"user_message": "Assignment commit payload is incomplete",
			"reported_at": _utc_now_string(),
		}
		return
	payload.erase("assignment_id")
	var path := ASSIGNMENT_COMMIT_PATH_TEMPLATE % assignment_id
	var response := await _send_internal_post_with_retry(path, payload)
	response["assignment_id"] = assignment_id
	response["reported_at"] = _utc_now_string()
	last_assignment_commit_status = response


func _build_finalize_payload(room_runtime: Node, result: BattleResult) -> Dictionary:
	if room_runtime == null or result == null:
		return {}
	var match_service = room_runtime.get_match_service() if room_runtime.has_method("get_match_service") else null
	var room_state = room_runtime.get_room_state() if room_runtime.has_method("get_room_state") else null
	if match_service == null or room_state == null:
		return {}
	var config: BattleStartConfig = null
	if match_service.has_method("get_last_finished_config"):
		config = match_service.get_last_finished_config()
	if config == null and match_service.has_method("get_current_config"):
		config = match_service.get_current_config()
	if config == null:
		return {}
	var match_id := String(match_service.get_last_finished_match_id()) if match_service.has_method("get_last_finished_match_id") else String(config.match_id)
	if match_id.is_empty():
		match_id = String(config.match_id)
	var room_id := String(match_service.get_last_finished_room_id()) if match_service.has_method("get_last_finished_room_id") else String(config.room_id)
	if room_id.is_empty():
		room_id = String(config.room_id)
	var assignment_id := String(room_state.assignment_id)
	if match_id.is_empty() or room_id.is_empty() or assignment_id.is_empty():
		return {}
	var payload := {
		"match_id": match_id,
		"assignment_id": assignment_id,
		"room_id": room_id,
		"room_kind": String(room_state.room_kind),
		"season_id": String(room_state.season_id),
		"mode_id": String(config.mode_id),
		"rule_set_id": String(config.rule_set_id),
		"map_id": String(config.map_id),
		"started_at": null,
		"finished_at": _utc_now_string(),
		"finish_reason": String(result.finish_reason),
		"score_policy": String(result.score_policy),
		"winner_team_ids": result.winner_team_ids.duplicate(),
		"winner_peer_ids": result.winner_peer_ids.duplicate(),
		"member_results": _build_member_results(room_state, result),
	}
	if payload["season_id"] == "":
		payload["season_id"] = "season_s1"
	return payload


func _build_member_results(room_state, result: BattleResult) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if room_state == null or result == null:
		return rows
	var bindings = room_state._get_sorted_member_bindings() if room_state.has_method("_get_sorted_member_bindings") else []
	for binding in bindings:
		if binding == null:
			continue
		var peer_id := int(binding.match_peer_id if binding.match_peer_id > 0 else binding.transport_peer_id)
		var team_id := int(binding.team_id)
		rows.append({
			"account_id": String(binding.account_id),
			"profile_id": String(binding.profile_id),
			"team_id": team_id,
			"peer_id": peer_id,
			"outcome": _resolve_outcome(result, peer_id, team_id),
			"player_score": int(result.player_scores.get(str(peer_id), 0)),
			"team_score": int(result.team_scores.get(str(team_id), 0)),
			"placement": _resolve_placement(result, peer_id, team_id),
		})
	return rows


func _resolve_outcome(result: BattleResult, peer_id: int, team_id: int) -> String:
	if result == null:
		return "draw"
	if result.winner_team_ids.is_empty() and result.winner_peer_ids.is_empty():
		return "draw"
	if team_id > 0 and result.winner_team_ids.has(team_id):
		return "win"
	if peer_id > 0 and result.winner_peer_ids.has(peer_id):
		return "win"
	return "loss"


func _resolve_placement(result: BattleResult, peer_id: int, team_id: int) -> int:
	var outcome := _resolve_outcome(result, peer_id, team_id)
	if outcome == "win" or outcome == "draw":
		return 1
	return 2


func _build_result_hash(payload: Dictionary) -> String:
	var hash_payload := payload.duplicate(true)
	hash_payload.erase("result_hash")
	hash_payload.erase("started_at")
	hash_payload.erase("finished_at")
	var bytes := JSON.stringify(hash_payload).to_utf8_buffer()
	var hashing := HashingContext.new()
	var err := hashing.start(HashingContext.HASH_SHA256)
	if err != OK:
		return "sha256:"
	hashing.update(bytes)
	return "sha256:%s" % hashing.finish().hex_encode()


func _send_finalize_request(payload: Dictionary) -> Dictionary:
	return await _send_internal_post_with_retry(FINALIZE_PATH, payload)


func _send_internal_post_with_retry(path: String, payload: Dictionary) -> Dictionary:
	var response: Dictionary = {}
	for attempt in range(retry_delays_msec.size() + 1):
		response = _send_internal_post_once(path, payload)
		if bool(response.get("ok", false)):
			return response
		if _is_terminal_internal_error(String(response.get("error_code", ""))):
			return response
		if attempt >= retry_delays_msec.size():
			return response
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			OS.delay_msec(int(retry_delays_msec[attempt]))
		else:
			await tree.create_timer(float(retry_delays_msec[attempt]) / 1000.0).timeout
	return response


func _send_internal_post_once(path: String, payload: Dictionary) -> Dictionary:
	if internal_shared_secret.strip_edges().is_empty():
		return {
			"ok": false,
			"error_code": "MATCH_FINALIZE_SECRET_MISSING",
			"user_message": "GAME_INTERNAL_SHARED_SECRET is missing",
		}
	var client := HTTPClient.new()
	var err := client.connect_to_host(game_service_host, game_service_port)
	if err != OK:
		return {
			"ok": false,
			"error_code": "MATCH_FINALIZE_CONNECT_FAILED",
			"user_message": "Failed to connect game service",
		}
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {
			"ok": false,
			"error_code": "MATCH_FINALIZE_CONNECT_FAILED",
			"user_message": "Failed to connect game service",
		}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Internal-Secret: %s" % internal_shared_secret,
	])
	err = client.request(HTTPClient.METHOD_POST, path, headers, JSON.stringify(payload))
	if err != OK:
		return {
			"ok": false,
			"error_code": "MATCH_FINALIZE_REQUEST_FAILED",
			"user_message": "Failed to send finalize request",
		}
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	var raw := client.read_response_body_chunk()
	var chunks := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY or not raw.is_empty():
		chunks.append_array(raw)
		client.poll()
		raw = client.read_response_body_chunk()
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return {
			"ok": false,
			"error_code": "MATCH_FINALIZE_EMPTY_RESPONSE",
			"user_message": "Game service returned empty finalize response",
		}
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {
			"ok": false,
			"error_code": "MATCH_FINALIZE_RESPONSE_INVALID",
			"user_message": "Game service returned invalid finalize response",
		}
	var response: Dictionary = json.data
	if not response.has("user_message") and response.has("message"):
		response["user_message"] = response.get("message", "")
	return response


func _is_terminal_internal_error(error_code: String) -> bool:
	match error_code:
		"MATCH_FINALIZE_HASH_MISMATCH", "MATCH_FINALIZE_CONTEXT_MISMATCH", "MATCH_FINALIZE_ASSIGNMENT_NOT_FOUND", "MATCH_FINALIZE_MEMBER_RESULT_INVALID", "MATCHMAKING_ASSIGNMENT_REVISION_STALE", "MATCHMAKING_ASSIGNMENT_GRANT_FORBIDDEN", "MATCHMAKING_ASSIGNMENT_EXPIRED":
			return true
		_:
			return false


func _read_env(name: String, fallback: String = "") -> String:
	var value := OS.get_environment(name).strip_edges()
	return value if not value.is_empty() else fallback


func _utc_now_string() -> String:
	return "%sZ" % Time.get_datetime_string_from_system(true, false)
