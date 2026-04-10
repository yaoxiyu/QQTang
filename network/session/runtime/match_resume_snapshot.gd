class_name MatchResumeSnapshot
extends RefCounted

var room_id: String = ""
var room_kind: String = ""
var room_display_name: String = ""
var match_id: String = ""
var server_match_revision: int = 0

var member_id: String = ""
var controlled_peer_id: int = 0
var transport_peer_id: int = 0

var resume_phase: String = ""
var resume_tick: int = 0
var checkpoint_message: Dictionary = {}
var player_summary: Array[Dictionary] = []
var status_message: String = ""

func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"match_id": match_id,
		"server_match_revision": server_match_revision,
		"member_id": member_id,
		"controlled_peer_id": controlled_peer_id,
		"transport_peer_id": transport_peer_id,
		"resume_phase": resume_phase,
		"resume_tick": resume_tick,
		"checkpoint_message": checkpoint_message.duplicate(true),
		"player_summary": player_summary.duplicate(true),
		"status_message": status_message,
	}

static func from_dict(data: Dictionary) -> MatchResumeSnapshot:
	var snapshot := MatchResumeSnapshot.new()
	snapshot.room_id = String(data.get("room_id", ""))
	snapshot.room_kind = String(data.get("room_kind", ""))
	snapshot.room_display_name = String(data.get("room_display_name", ""))
	snapshot.match_id = String(data.get("match_id", ""))
	snapshot.server_match_revision = int(data.get("server_match_revision", 0))
	snapshot.member_id = String(data.get("member_id", ""))
	snapshot.controlled_peer_id = int(data.get("controlled_peer_id", 0))
	snapshot.transport_peer_id = int(data.get("transport_peer_id", 0))
	snapshot.resume_phase = String(data.get("resume_phase", ""))
	snapshot.resume_tick = int(data.get("resume_tick", 0))
	snapshot.checkpoint_message = Dictionary(data.get("checkpoint_message", {})).duplicate(true)
	var raw_summary: Array = data.get("player_summary", [])
	for entry in raw_summary:
		if entry is Dictionary:
			snapshot.player_summary.append(entry.duplicate(true))
	snapshot.status_message = String(data.get("status_message", ""))
	return snapshot