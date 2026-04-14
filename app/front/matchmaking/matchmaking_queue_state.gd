class_name MatchmakingQueueState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/matchmaking/matchmaking_queue_state.gd")

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var queue_entry_id: String = ""
var queue_state: String = ""
var queue_key: String = ""
var queue_type: String = ""
var match_format_id: String = ""
var mode_id: String = ""
var selected_map_ids: Array[String] = []
var queue_status_text: String = ""
var enqueue_unix_sec: int = 0
var last_heartbeat_unix_sec: int = 0
var expires_at_unix_sec: int = 0


static func from_response(data: Dictionary, p_queue_type: String = "") -> MatchmakingQueueState:
	var state := SELF_SCRIPT.new()
	state.ok = bool(data.get("ok", false))
	state.error_code = String(data.get("error_code", ""))
	state.user_message = String(data.get("user_message", data.get("message", "")))
	state.queue_entry_id = String(data.get("queue_entry_id", ""))
	state.queue_state = String(data.get("queue_state", ""))
	state.queue_key = String(data.get("queue_key", ""))
	state.queue_type = p_queue_type if not p_queue_type.is_empty() else String(data.get("queue_type", ""))
	state.match_format_id = String(data.get("match_format_id", ""))
	state.mode_id = String(data.get("mode_id", ""))
	state.selected_map_ids = _to_string_array(data.get("selected_map_ids", []))
	state.queue_status_text = String(data.get("queue_status_text", ""))
	state.enqueue_unix_sec = int(data.get("enqueue_unix_sec", 0))
	state.last_heartbeat_unix_sec = int(data.get("last_heartbeat_unix_sec", 0))
	state.expires_at_unix_sec = int(data.get("expires_at_unix_sec", 0))
	return state


static func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (values is Array):
		return result
	for value in values:
		result.append(String(value))
	return result
