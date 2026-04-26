extends SubViewportContainer
class_name RoomCharacterPreview

const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const SkinApplierScript = preload("res://presentation/runtime/skin_applier.gd")

const PREVIEW_BODY_ORIGIN := Vector2(90, 150)
const PREVIEW_STATE_INTERVAL_SEC := 0.8
const PREVIEW_STATES := [
	{"facing": 1, "input_move_x": 0, "input_move_y": 1},
	{"facing": 2, "input_move_x": -1, "input_move_y": 0},
	{"facing": 3, "input_move_x": 1, "input_move_y": 0},
	{"facing": 0, "input_move_x": 0, "input_move_y": -1},
]

@onready var _preview_root: Node2D = get_node_or_null("PreviewViewport/PreviewRoot")

var _body_view: Node2D = null
var _preview_state_index: int = 0
var _preview_state_elapsed: float = 0.0


func _process(delta: float) -> void:
	if _body_view == null:
		return
	_preview_state_elapsed += delta
	if _preview_state_elapsed < PREVIEW_STATE_INTERVAL_SEC:
		return
	_preview_state_elapsed = 0.0
	_preview_state_index = (_preview_state_index + 1) % PREVIEW_STATES.size()
	_apply_preview_state()


func configure_preview(character_id: String, character_skin_id: String = "") -> void:
	_preview_root = get_node_or_null("PreviewViewport/PreviewRoot")
	if _preview_root == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing PreviewRoot for %s" % character_id)
		return
	_clear_current_body_view()
	_preview_state_index = 0
	_preview_state_elapsed = 0.0

	var character_presentation := CharacterLoaderScript.load_character_presentation(character_id)
	if character_presentation == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing CharacterPresentationDef for %s" % character_id)
		return
	if character_presentation.body_scene == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing body_scene for %s" % character_id)
		return

	var animation_set_id := String(character_presentation.animation_set_id)
	if animation_set_id.is_empty():
		push_error("RoomCharacterPreview.configure_preview failed: empty animation_set_id for %s" % character_id)
		return
	var animation_set := CharacterAnimationSetLoaderScript.load_animation_set(animation_set_id)
	if animation_set == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing CharacterAnimationSetDef for %s" % animation_set_id)
		return

	var body_instance := character_presentation.body_scene.instantiate()
	if body_instance == null or not body_instance is Node2D:
		push_error("RoomCharacterPreview.configure_preview failed: body_scene instantiate failed for %s" % character_id)
		return

	_body_view = body_instance as Node2D
	_body_view.position = PREVIEW_BODY_ORIGIN
	_preview_root.add_child(_body_view)

	if not _body_view.has_method("setup_from_animation_set"):
		push_error("RoomCharacterPreview.configure_preview failed: body_view missing setup_from_animation_set for %s" % character_id)
		_clear_current_body_view()
		return
	_body_view.call("setup_from_animation_set", animation_set)

	if not character_skin_id.is_empty():
		var character_skin := CharacterSkinCatalogScript.get_by_id(character_skin_id)
		if character_skin == null:
			push_error("RoomCharacterPreview.configure_preview failed: missing CharacterSkinDef for %s" % character_skin_id)
			_clear_current_body_view()
			return
		SkinApplierScript.new().apply_character_skin(_body_view, character_skin)

	_apply_preview_state()


func _apply_preview_state() -> void:
	if _body_view == null or not _body_view.has_method("apply_actor_state"):
		return
	var preview_state: Dictionary = PREVIEW_STATES[_preview_state_index]
	_body_view.call("apply_actor_state", {
		"alive": true,
		"facing": int(preview_state.get("facing", 1)),
		"move_state": 1,
		"input_move_x": int(preview_state.get("input_move_x", 0)),
		"input_move_y": int(preview_state.get("input_move_y", 0)),
	})


func _clear_current_body_view() -> void:
	if _body_view == null:
		return
	if _body_view.get_parent() == _preview_root:
		_preview_root.remove_child(_body_view)
	_body_view.queue_free()
	_body_view = null
