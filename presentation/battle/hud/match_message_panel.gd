class_name MatchMessagePanel
extends Label

var current_message: String = ""


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false
	text = ""


func apply_message(message: String) -> void:
	current_message = message
	text = current_message
	visible = not current_message.is_empty()
