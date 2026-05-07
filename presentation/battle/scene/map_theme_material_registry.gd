class_name MapThemeMaterialRegistry
extends RefCounted


static func get_theme_materials(theme_id: String) -> Dictionary:
	return {
		"theme_dir": theme_id,
		"ground": null,
		"ground_variants": [],
		"solid_base": null,
		"solid_overlay": null,
		"breakable_block": null,
		"spawn_marker": null,
		"environment_background": null,
		"occluders": {
			"primary": null,
			"secondary": null,
		},
	}
