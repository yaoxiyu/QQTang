class_name Phase3DebugTools
extends Node

const DEFAULT_MAP_ID: String = "default_map"
const DEFAULT_RULE_SET_ID: String = "classic"
const DEFAULT_REMOTE_NAME: String = "RemoteFox"
const DEFAULT_REMOTE_CHARACTER_ID: String = "hero_remote"

var local_loop_enabled: bool = true


func ensure_local_loop_room(room_controller: Node, local_peer_id: int, remote_peer_id: int) -> void:
	if not local_loop_enabled or room_controller == null:
		return

	if room_controller.room_session.peers.is_empty():
		room_controller.create_room(local_peer_id)
		var remote_member := RoomMemberState.new()
		remote_member.peer_id = remote_peer_id
		remote_member.player_name = DEFAULT_REMOTE_NAME
		remote_member.ready = true
		remote_member.slot_index = 1
		remote_member.character_id = DEFAULT_REMOTE_CHARACTER_ID
		room_controller.join_room(remote_member)
		room_controller.set_room_selection(DEFAULT_MAP_ID, DEFAULT_RULE_SET_ID)
		return

	if room_controller.room_session.peers.size() == 2 and room_controller.room_session.peers.has(local_peer_id) and room_controller.room_session.peers.has(remote_peer_id):
		room_controller.set_member_ready(local_peer_id, false)
		room_controller.set_member_ready(remote_peer_id, true)
		if room_controller.room_session.selected_map.is_empty() or room_controller.room_session.selected_mode.is_empty():
			room_controller.set_room_selection(DEFAULT_MAP_ID, DEFAULT_RULE_SET_ID)


func reset_local_loop_room_ready(room_controller: Node, local_peer_id: int, remote_peer_id: int) -> void:
	if not local_loop_enabled or room_controller == null:
		return
	if room_controller.room_session.peers.size() == 2 and room_controller.room_session.peers.has(local_peer_id) and room_controller.room_session.peers.has(remote_peer_id):
		room_controller.set_member_ready(local_peer_id, false)
		room_controller.set_member_ready(remote_peer_id, true)


func debug_dump() -> Dictionary:
	return {
		"local_loop_enabled": local_loop_enabled,
	}
