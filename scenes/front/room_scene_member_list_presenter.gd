class_name RoomSceneMemberListPresenter
extends RefCounted


func present(members_data, member_list: VBoxContainer) -> void:
	if member_list == null:
		return
	for child in member_list.get_children():
		child.queue_free()
	for entry in members_data:
		if not (entry is Dictionary):
			continue
		var label := Label.new()
		label.text = _build_member_text(entry)
		member_list.add_child(label)


func _build_member_text(entry: Dictionary) -> String:
	var owner_suffix := " [Host]" if bool(entry.get("is_owner", false)) else ""
	var local_suffix := " [You]" if bool(entry.get("is_local_player", false)) else ""
	var team_suffix := " | Team %d" % int(entry.get("team_id", 1))
	var ready_suffix := " Ready" if bool(entry.get("ready", false)) else " Not Ready"
	var connection_state := String(entry.get("connection_state", "connected"))
	var connection_suffix := "" if connection_state.is_empty() or connection_state == "connected" else " [%s]" % connection_state
	return "%s%s%s%s%s%s" % [
		String(entry.get("player_name", "")),
		owner_suffix,
		local_suffix,
		team_suffix,
		ready_suffix,
		connection_suffix,
	]
