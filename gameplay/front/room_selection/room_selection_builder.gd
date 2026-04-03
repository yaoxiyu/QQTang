class_name RoomSelectionBuilder
extends RefCounted


static func build_selection_state(
	mode_id: String,
	map_id: String,
	rule_set_id: String,
	player_states: Array[Dictionary]
) -> Dictionary:
	var players: Dictionary = {}
	for player_state in player_states:
		var peer_id := int(player_state.get("peer_id", -1))
		if peer_id < 0:
			continue
		players[peer_id] = {
			"peer_id": peer_id,
			"character_id": String(player_state.get("character_id", "")),
			"character_skin_id": String(player_state.get("character_skin_id", "")),
			"bubble_style_id": String(player_state.get("bubble_style_id", "")),
			"bubble_skin_id": String(player_state.get("bubble_skin_id", "")),
			"ready": bool(player_state.get("ready", false)),
		}

	return {
		"mode_id": mode_id,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"players": players,
	}
