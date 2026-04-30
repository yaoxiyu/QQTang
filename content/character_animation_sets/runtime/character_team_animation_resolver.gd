class_name CharacterTeamAnimationResolver
extends RefCounted

const CharacterAnimationSetCatalogScript = preload("res://content/character_animation_sets/catalog/character_animation_set_catalog.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")


static func resolve_animation_set_id(base_animation_set_id: String, team_id: int, require_variant: bool = false) -> String:
	if base_animation_set_id.is_empty():
		return ""
	if team_id < 1:
		if require_variant:
			push_error("CharacterTeamAnimationResolver invalid team_id: %d" % team_id)
		return base_animation_set_id
	var variant_id := "%s_team_%02d" % [base_animation_set_id, team_id]
	if CharacterAnimationSetLoaderScript.can_load_animation_set(variant_id) or CharacterAnimationSetCatalogScript.has_id(variant_id):
		return variant_id
	if require_variant:
		push_error("CharacterTeamAnimationResolver missing team animation set: %s" % variant_id)
	return base_animation_set_id
