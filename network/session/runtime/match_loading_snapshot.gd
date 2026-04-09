class_name MatchLoadingSnapshot
extends RefCounted

var room_id: String = ""
var room_kind: String = ""
var room_display_name: String = ""
var match_id: String = ""
var revision: int = 0
var phase: String = "waiting"
var owner_peer_id: int = 0
var expected_peer_ids: Array[int] = []
var ready_peer_ids: Array[int] = []
var waiting_peer_ids: Array[int] = []
var battle_seed: int = 0
var error_code: String = ""
var user_message: String = ""


func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"match_id": match_id,
		"revision": revision,
		"phase": phase,
		"owner_peer_id": owner_peer_id,
		"expected_peer_ids": expected_peer_ids.duplicate(),
		"ready_peer_ids": ready_peer_ids.duplicate(),
		"waiting_peer_ids": waiting_peer_ids.duplicate(),
		"battle_seed": battle_seed,
		"error_code": error_code,
		"user_message": user_message,
	}


static func from_dict(data: Dictionary) -> MatchLoadingSnapshot:
	var snapshot := MatchLoadingSnapshot.new()
	snapshot.room_id = data.get("room_id", "")
	snapshot.room_kind = data.get("room_kind", "")
	snapshot.room_display_name = data.get("room_display_name", "")
	snapshot.match_id = data.get("match_id", "")
	snapshot.revision = data.get("revision", 0)
	snapshot.phase = data.get("phase", "waiting")
	snapshot.owner_peer_id = data.get("owner_peer_id", 0)
	snapshot.battle_seed = data.get("battle_seed", 0)
	snapshot.error_code = data.get("error_code", "")
	snapshot.user_message = data.get("user_message", "")

	var expected_raw = data.get("expected_peer_ids", [])
	if expected_raw is Array:
		snapshot.expected_peer_ids = Array(expected_raw, TYPE_INT, "", null)

	var ready_raw = data.get("ready_peer_ids", [])
	if ready_raw is Array:
		snapshot.ready_peer_ids = Array(ready_raw, TYPE_INT, "", null)

	var waiting_raw = data.get("waiting_peer_ids", [])
	if waiting_raw is Array:
		snapshot.waiting_peer_ids = Array(waiting_raw, TYPE_INT, "", null)

	snapshot._recalculate_waiting_peers()
	return snapshot


func duplicate_deep() -> MatchLoadingSnapshot:
	var copy := MatchLoadingSnapshot.new()
	copy.room_id = room_id
	copy.room_kind = room_kind
	copy.room_display_name = room_display_name
	copy.match_id = match_id
	copy.revision = revision
	copy.phase = phase
	copy.owner_peer_id = owner_peer_id
	copy.expected_peer_ids = expected_peer_ids.duplicate()
	copy.ready_peer_ids = ready_peer_ids.duplicate()
	copy.waiting_peer_ids = waiting_peer_ids.duplicate()
	copy.battle_seed = battle_seed
	copy.error_code = error_code
	copy.user_message = user_message
	return copy


func is_committed() -> bool:
	return phase == "committed"


func is_aborted() -> bool:
	return phase == "aborted"


func _recalculate_waiting_peers() -> void:
	var waiting: Array[int] = []
	for peer_id in expected_peer_ids:
		if not ready_peer_ids.has(peer_id):
			waiting.append(peer_id)
	waiting_peer_ids = waiting
