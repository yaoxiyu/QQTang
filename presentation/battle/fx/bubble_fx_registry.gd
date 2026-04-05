class_name BubbleFxRegistry
extends RefCounted

const DEFAULT_EXPLOSION_STYLE := {
	"fill_color": Color(1.0, 0.72, 0.18, 0.55),
	"outline_color": Color(1.0, 0.94, 0.65, 0.9),
	"core_color": Color(1.0, 0.98, 0.82, 0.95),
	"tail_alpha": 0.72,
	"lifetime": 0.18,
}

const DEFAULT_SPAWN_STYLE := {
	"fill_color": Color(0.62, 0.82, 1.0, 0.55),
	"outline_color": Color(0.92, 0.97, 1.0, 0.92),
	"flash_color": Color(1.0, 1.0, 1.0, 0.95),
	"lifetime": 0.20,
}

const EXPLOSION_STYLE_OVERRIDES := {
	"bubble_explode_normal": {
		"fill_color_mul": Color(1.00, 0.86, 0.46, 1.0),
		"outline_color_mul": Color(1.00, 0.98, 0.82, 1.0),
		"core_color_mul": Color(1.00, 1.00, 0.92, 1.0),
		"tail_alpha": 0.72,
		"lifetime": 0.18,
	},
}

const SPAWN_STYLE_OVERRIDES := {
	"bubble_spawn_normal": {
		"fill_color_mul": Color(0.88, 0.96, 1.0, 1.0),
		"outline_color_mul": Color(1.0, 1.0, 1.0, 1.0),
		"flash_color_mul": Color(1.0, 1.0, 1.0, 1.0),
		"lifetime": 0.20,
	},
}


static func get_explosion_style(explode_fx_id: String, bubble_color: Color = Color.WHITE) -> Dictionary:
	var style := DEFAULT_EXPLOSION_STYLE.duplicate(true)
	var overrides: Dictionary = EXPLOSION_STYLE_OVERRIDES.get(explode_fx_id, {})
	style["fill_color"] = _resolve_color_variant(
		Color(style.get("fill_color", Color.WHITE)),
		Color(overrides.get("fill_color_mul", Color.WHITE)),
		bubble_color,
		0.35
	)
	style["outline_color"] = _resolve_color_variant(
		Color(style.get("outline_color", Color.WHITE)),
		Color(overrides.get("outline_color_mul", Color.WHITE)),
		bubble_color.lightened(0.20),
		0.22
	)
	style["core_color"] = _resolve_color_variant(
		Color(style.get("core_color", Color.WHITE)),
		Color(overrides.get("core_color_mul", Color.WHITE)),
		bubble_color.lightened(0.35),
		0.18
	)
	style["tail_alpha"] = float(overrides.get("tail_alpha", style.get("tail_alpha", 0.72)))
	style["lifetime"] = float(overrides.get("lifetime", style.get("lifetime", 0.18)))
	return style


static func get_spawn_style(spawn_fx_id: String, bubble_color: Color = Color.WHITE) -> Dictionary:
	var style := DEFAULT_SPAWN_STYLE.duplicate(true)
	var overrides: Dictionary = SPAWN_STYLE_OVERRIDES.get(spawn_fx_id, {})
	style["fill_color"] = _resolve_color_variant(
		Color(style.get("fill_color", Color.WHITE)),
		Color(overrides.get("fill_color_mul", Color.WHITE)),
		bubble_color,
		0.28
	)
	style["outline_color"] = _resolve_color_variant(
		Color(style.get("outline_color", Color.WHITE)),
		Color(overrides.get("outline_color_mul", Color.WHITE)),
		bubble_color.lightened(0.25),
		0.18
	)
	style["flash_color"] = _resolve_color_variant(
		Color(style.get("flash_color", Color.WHITE)),
		Color(overrides.get("flash_color_mul", Color.WHITE)),
		bubble_color.lightened(0.40),
		0.12
	)
	style["lifetime"] = float(overrides.get("lifetime", style.get("lifetime", 0.20)))
	return style


static func _resolve_color_variant(base_color: Color, style_multiplier: Color, bubble_color: Color, bubble_weight: float) -> Color:
	var tinted := Color(
		base_color.r * style_multiplier.r,
		base_color.g * style_multiplier.g,
		base_color.b * style_multiplier.b,
		base_color.a
	)
	return tinted.lerp(bubble_color, clamp(bubble_weight, 0.0, 1.0))
