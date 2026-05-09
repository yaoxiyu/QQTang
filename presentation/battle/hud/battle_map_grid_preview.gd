@tool
extends Control

@export var columns: int = 15
@export var rows: int = 13
@export var cell_size: float = 40.0
@export var fill_color: Color = Color(0.20, 0.25, 0.30, 0.18)
@export var line_color: Color = Color(0.70, 0.85, 1.0, 0.55)
@export var border_color: Color = Color(0.85, 0.95, 1.0, 0.85)


func _ready() -> void:
	_update_rect_size()
	_update_visibility()
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_update_rect_size()
	_update_visibility()
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var total_w := float(columns) * cell_size
	var total_h := float(rows) * cell_size
	draw_rect(Rect2(Vector2.ZERO, Vector2(total_w, total_h)), fill_color, true)
	for x in range(columns + 1):
		var px := float(x) * cell_size
		draw_line(Vector2(px, 0.0), Vector2(px, total_h), line_color, 1.0)
	for y in range(rows + 1):
		var py := float(y) * cell_size
		draw_line(Vector2(0.0, py), Vector2(total_w, py), line_color, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(total_w, total_h)), border_color, false, 2.0)


func _update_rect_size() -> void:
	custom_minimum_size = Vector2(float(columns) * cell_size, float(rows) * cell_size)
	size = custom_minimum_size


func _update_visibility() -> void:
	visible = Engine.is_editor_hint()
