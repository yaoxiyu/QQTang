class_name MapThemeMaterialRegistry
extends RefCounted

const THEME_ROOT := "res://assets/map_themes"
const DEFAULT_THEME_DIR := "grassland"

const THEME_DIR_BY_ID := {
	"map_theme_default": "grassland",
	"map_theme_snow": "snowfield",
	"map_theme_desert": "desert",
}

const OCCLUDER_FILES_BY_DIR := {
	"grassland": {
		"primary": "occluder_tall_grass.png",
		"secondary": "occluder_tree_small.png",
	},
	"snowfield": {
		"primary": "occluder_snow_drift.png",
		"secondary": "occluder_pine_small.png",
	},
	"desert": {
		"primary": "occluder_dune_small.png",
		"secondary": "occluder_cactus_small.png",
	},
}


static func get_theme_materials(theme_id: String) -> Dictionary:
	var theme_dir := _resolve_theme_dir(theme_id)
	var base_path := "%s/%s" % [THEME_ROOT, theme_dir]
	var occluder_files: Dictionary = OCCLUDER_FILES_BY_DIR.get(theme_dir, OCCLUDER_FILES_BY_DIR.get(DEFAULT_THEME_DIR, {}))
	return {
		"theme_dir": theme_dir,
		"ground": load("%s/ground.png" % base_path) as Texture2D,
		"ground_variants": [
			load("%s/ground_variant_a.png" % base_path) as Texture2D,
			load("%s/ground_variant_b.png" % base_path) as Texture2D,
		],
		"solid_base": load("%s/solid_base.png" % base_path) as Texture2D,
		"solid_overlay": load("%s/solid_overlay.png" % base_path) as Texture2D,
		"breakable_block": load("%s/breakable_block.png" % base_path) as Texture2D,
		"spawn_marker": load("%s/spawn_marker.png" % base_path) as Texture2D,
		"environment_background": load("%s/environment_background.png" % base_path) as Texture2D,
		"occluders": {
			"primary": load("%s/%s" % [base_path, String(occluder_files.get("primary", ""))]) as Texture2D,
			"secondary": load("%s/%s" % [base_path, String(occluder_files.get("secondary", ""))]) as Texture2D,
		},
	}


static func _resolve_theme_dir(theme_id: String) -> String:
	return String(THEME_DIR_BY_ID.get(theme_id, DEFAULT_THEME_DIR))
