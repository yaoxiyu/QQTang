class_name BattleSpawnFxController
extends Node

const ExplosionActorViewScript = preload("res://presentation/battle/actors/explosion_actor_view.gd")
const CorrectionMarkerViewScript = preload("res://presentation/battle/actors/correction_marker_view.gd")

@export var fx_layer_path: NodePath = ^"../WorldRoot/FxLayer"

var fx_layer: Node2D = null


func _ready() -> void:
	if has_node(fx_layer_path):
		fx_layer = get_node(fx_layer_path) as Node2D


func spawn_explosion(
	event: SimEvent,
	cell_size: float,
	bubble_style_id: String = "",
	bubble_color: Color = Color.WHITE
) -> void:
	if fx_layer == null or event == null:
		return
	var cells: Array[Vector2i] = []
	for cell in event.payload.get("covered_cells", []):
		cells.append(cell)
	var view: BattleExplosionActorView = ExplosionActorViewScript.new()
	view.configure(cells, cell_size, bubble_style_id, bubble_color)
	fx_layer.add_child(view)


func show_prediction_correction(from_pos: Vector2, to_pos: Vector2) -> void:
	if fx_layer == null:
		return
	var marker := CorrectionMarkerViewScript.new()
	marker.configure(from_pos, to_pos)
	fx_layer.add_child(marker)


func clear_fx() -> void:
	if fx_layer == null:
		return
	for child in fx_layer.get_children():
		child.free()


func dispose() -> void:
	clear_fx()
	fx_layer = null


func debug_dump_fx_state() -> Dictionary:
	return {
		"has_fx_layer": fx_layer != null,
		"fx_children": fx_layer.get_child_count() if fx_layer != null else 0,
	}

