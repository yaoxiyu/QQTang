class_name PlayerStatusPanel
extends Label

var _player_lines: Array[String] = []


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text = "Players"


func apply_player_statuses(player_statuses: Array[Dictionary]) -> void:
	_player_lines.clear()
	for player_status in player_statuses:
		var slot := int(player_status.get("player_slot", -1))
		var alive := bool(player_status.get("alive", false))
		var life_state := String(player_status.get("life_state_text", "UNKNOWN"))
		var bomb_available := int(player_status.get("bomb_available", 0))
		var bomb_capacity := int(player_status.get("bomb_capacity", 0))
		var bomb_range := int(player_status.get("bomb_range", 0))
		var status_text := "DEAD"
		if alive:
			status_text = "ALIVE"
		_player_lines.append(
			"P%d  %s  %s  Bomb %d/%d  Range %d" % [
				slot + 1,
				status_text,
				life_state,
				bomb_available,
				bomb_capacity,
				bomb_range
			]
		)

	text = "\n".join(_player_lines)
