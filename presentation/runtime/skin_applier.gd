extends RefCounted
class_name SkinApplier

func slot_to_anchor_name(slot_name: String) -> String:
	match slot_name:
		"body_overlay":
			return "SkinAnchor_BodyOverlay"
		"head_overlay":
			return "SkinAnchor_HeadOverlay"
		"back_overlay":
			return "SkinAnchor_BackOverlay"
		"front_overlay":
			return "SkinAnchor_FrontOverlay"
		_:
			return ""

func apply_character_skin(character_root: Node, skin_def: CharacterSkinDef) -> void:
	if character_root == null:
		push_error("apply_character_skin: character_root is null")
		return
	if skin_def == null:
		return
	if skin_def.overlay_scene == null:
		push_error("apply_character_skin: overlay_scene is null for skin %s" % skin_def.skin_id)
		return

	for slot_name in skin_def.applicable_slots:
		var anchor_name := slot_to_anchor_name(slot_name)
		if anchor_name == "":
			push_error("Unknown skin slot: %s" % slot_name)
			continue

		var anchor := character_root.get_node_or_null(anchor_name)
		if anchor == null:
			push_error("Missing anchor: %s" % anchor_name)
			continue

		var overlay_instance := skin_def.overlay_scene.instantiate()
		if overlay_instance == null:
			push_error("Failed to instantiate overlay_scene for skin %s" % skin_def.skin_id)
			continue

		anchor.add_child(overlay_instance)

		if skin_def.slot_offsets.has(slot_name):
			var offset_value = skin_def.slot_offsets[slot_name]
			if overlay_instance is Node2D and offset_value is Vector2:
				(overlay_instance as Node2D).position = offset_value
