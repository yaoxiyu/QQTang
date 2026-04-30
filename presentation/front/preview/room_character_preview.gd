extends SubViewportContainer
class_name RoomCharacterPreview

const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterTeamAnimationResolverScript = preload("res://content/character_animation_sets/runtime/character_team_animation_resolver.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const SkinApplierScript = preload("res://presentation/runtime/skin_applier.gd")

const PREVIEW_BODY_ORIGIN := Vector2(90, 150)
const TEAM_MARKER_Z_INDEX := -10

@onready var _preview_root: Node2D = get_node_or_null("PreviewViewport/PreviewRoot")

var _body_view: Node2D = null
var _team_marker_view: Node2D = null
var _preview_team_id: int = 0
var _configured_character_id: String = ""
var _configured_character_skin_id: String = ""
var _configured_team_id: int = -1


func configure_preview(character_id: String, character_skin_id: String = "", team_id: int = 0) -> void:
	var normalized_character_id := character_id.strip_edges()
	var normalized_skin_id := character_skin_id.strip_edges()
	if _body_view != null \
		and normalized_character_id == _configured_character_id \
		and normalized_skin_id == _configured_character_skin_id \
		and team_id == _configured_team_id:
		_apply_preview_state()
		return
	_preview_root = get_node_or_null("PreviewViewport/PreviewRoot")
	if _preview_root == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing PreviewRoot for %s" % character_id)
		return
	_clear_current_body_view()
	_preview_team_id = team_id
	_configured_character_id = normalized_character_id
	_configured_character_skin_id = normalized_skin_id
	_configured_team_id = team_id

	var character_presentation := CharacterLoaderScript.load_character_presentation(normalized_character_id)
	var character_metadata := CharacterLoaderScript.load_character_metadata(normalized_character_id)
	if character_presentation == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing CharacterPresentationDef for %s" % character_id)
		_clear_configured_keys()
		return
	if character_presentation.body_scene == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing body_scene for %s" % character_id)
		_clear_configured_keys()
		return

	var animation_set_id := String(character_presentation.animation_set_id)
	if animation_set_id.is_empty():
		push_error("RoomCharacterPreview.configure_preview failed: empty animation_set_id for %s" % character_id)
		_clear_configured_keys()
		return
	var resolved_animation_set_id := CharacterTeamAnimationResolverScript.resolve_animation_set_id(animation_set_id, team_id, false)
	var animation_set := CharacterAnimationSetLoaderScript.load_animation_set(resolved_animation_set_id)
	if animation_set == null:
		push_error("RoomCharacterPreview.configure_preview failed: missing CharacterAnimationSetDef for %s" % resolved_animation_set_id)
		_clear_configured_keys()
		return

	var body_instance := character_presentation.body_scene.instantiate()
	if body_instance == null or not body_instance is Node2D:
		push_error("RoomCharacterPreview.configure_preview failed: body_scene instantiate failed for %s" % character_id)
		_clear_configured_keys()
		return

	_body_view = body_instance as Node2D
	_body_view.position = PREVIEW_BODY_ORIGIN
	_preview_root.add_child(_body_view)
	_rebuild_team_marker_view(character_presentation, int(character_metadata.get("type", 0)), team_id)

	if not _body_view.has_method("setup_from_animation_set"):
		push_error("RoomCharacterPreview.configure_preview failed: body_view missing setup_from_animation_set for %s" % character_id)
		_clear_current_body_view()
		_clear_configured_keys()
		return
	_body_view.call("setup_from_animation_set", animation_set)

	if not normalized_skin_id.is_empty():
		var character_skin := CharacterSkinCatalogScript.get_by_id(normalized_skin_id)
		if character_skin == null:
			push_error("RoomCharacterPreview.configure_preview failed: missing CharacterSkinDef for %s" % normalized_skin_id)
			_clear_current_body_view()
			_clear_configured_keys()
			return
		SkinApplierScript.new().apply_character_skin(_body_view, character_skin)

	_apply_preview_state()


func _apply_preview_state() -> void:
	if _body_view == null or not _body_view.has_method("apply_actor_state"):
		return
	var state := {
		"alive": true,
		"facing": 3,
		"move_state": 0,
		"anim_is_moving": false,
		"pose_state": "wait",
		"dynamic_color_enabled": false,
		"dynamic_color": Color.WHITE,
	}
	_body_view.call("apply_actor_state", state)
	if _team_marker_view != null and _team_marker_view.has_method("apply_actor_state"):
		_team_marker_view.call("apply_actor_state", state)


func _clear_current_body_view() -> void:
	if _body_view == null:
		if _team_marker_view != null:
			_team_marker_view.queue_free()
			_team_marker_view = null
		return
	if _body_view.get_parent() == _preview_root:
		_preview_root.remove_child(_body_view)
	_body_view.queue_free()
	_body_view = null
	if _team_marker_view != null:
		if _team_marker_view.get_parent() == _preview_root:
			_preview_root.remove_child(_team_marker_view)
		_team_marker_view.queue_free()
		_team_marker_view = null


func _clear_configured_keys() -> void:
	_configured_character_id = ""
	_configured_character_skin_id = ""
	_configured_team_id = -1


func _rebuild_team_marker_view(character_presentation, character_type: int, team_id: int) -> void:
	if character_type != 4 or team_id < 1 or character_presentation == null:
		return
	var marker_animation_set := CharacterAnimationSetLoaderScript.load_animation_set("team_marker_leg1_team_%02d" % team_id)
	if marker_animation_set == null:
		return
	var marker_instance = character_presentation.body_scene.instantiate()
	if marker_instance == null or not marker_instance is Node2D:
		return
	_team_marker_view = marker_instance as Node2D
	_team_marker_view.position = PREVIEW_BODY_ORIGIN
	_team_marker_view.z_as_relative = true
	_team_marker_view.z_index = TEAM_MARKER_Z_INDEX
	_preview_root.add_child(_team_marker_view)
	if _team_marker_view.has_method("setup_from_animation_set"):
		_team_marker_view.call("setup_from_animation_set", marker_animation_set)
