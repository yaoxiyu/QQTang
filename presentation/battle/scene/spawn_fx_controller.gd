class_name BattleSpawnFxController
extends Node

const ExplosionActorViewScript = preload("res://presentation/battle/actors/explosion_actor_view.gd")
const CorrectionMarkerViewScript = preload("res://presentation/battle/actors/correction_marker_view.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")

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
	if cells.is_empty() and event.payload.has("cell_x") and event.payload.has("cell_y"):
		cells.append(Vector2i(int(event.payload.get("cell_x", 0)), int(event.payload.get("cell_y", 0))))
	var view: BattleExplosionActorView = ExplosionActorViewScript.new()
	view.configure(cells, cell_size, bubble_style_id, bubble_color)
	fx_layer.add_child(view)
	LogPresentationScript.info(
		"QQT_EXPLOSION_TRACE stage=spawn_fx event_tick=%d bubble_id=%d owner=%d cells=%d fx_children=%d style=%s color=%s payload_keys=%s" % [
			int(event.tick),
			int(event.payload.get("bubble_id", event.payload.get("entity_id", -1))),
			int(event.payload.get("owner_player_id", -1)),
			cells.size(),
			fx_layer.get_child_count(),
			bubble_style_id,
			str(bubble_color),
			str(event.payload.keys()),
		],
		"",
		0,
		"presentation.fx.explosion"
	)


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
