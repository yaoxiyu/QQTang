class_name CountdownPanel
extends Label

const WorldTiming = preload("res://gameplay/shared/world_timing.gd")

var remaining_ticks: int = 0
var tick_rate: int = WorldTiming.TICK_RATE
var countdown_text: String = ""


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_refresh_text()


func apply_countdown(remaining_tick_count: int, battle_tick_rate: int = WorldTiming.TICK_RATE) -> void:
	remaining_ticks = max(remaining_tick_count, 0)
	tick_rate = max(battle_tick_rate, 1)
	_refresh_text()


func apply_message(message: String) -> void:
	countdown_text = message
	text = countdown_text


func _refresh_text() -> void:
	var total_seconds := int(ceil(float(remaining_ticks) / float(max(tick_rate, 1))))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	countdown_text = "%02d:%02d" % [minutes, seconds]
	text = countdown_text
