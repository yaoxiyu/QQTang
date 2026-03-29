class_name RoomHudController
extends Node


func build_member_line(member: RoomMemberState, owner_peer_id: int) -> String:
	var owner_text := " [Owner]" if member.peer_id == owner_peer_id else ""
	var ready_text := "Ready" if member.ready else "Not Ready"
	return "P%d  %s  %s%s" % [member.slot_index + 1, member.player_name, ready_text, owner_text]


func build_debug_text(snapshot: RoomSnapshot, flow_state_name: StringName) -> String:
	if snapshot == null:
		return ""
	var lines := [
		"Room: %s" % snapshot.room_id,
		"Owner: %d" % snapshot.owner_peer_id,
		"Map: %s" % snapshot.selected_map_id,
		"Rule: %s" % snapshot.rule_set_id,
		"AllReady: %s" % str(snapshot.all_ready),
		"Flow: %s" % String(flow_state_name)
	]
	return "\n".join(lines)
