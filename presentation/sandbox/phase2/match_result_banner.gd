class_name Phase2MatchResultBanner
extends Label


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false
	text = ""
	modulate = Color(1.0, 0.95, 0.65, 1.0)
	scale = Vector2(1.4, 1.4)


func apply_result(result_text: String, is_visible: bool) -> void:
	text = result_text
	visible = is_visible and not result_text.is_empty()
