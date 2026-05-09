@tool
class_name BattleCountdownDigits
extends Control

const UiAssetResolverScript = preload("res://app/front/ui_resources/ui_asset_resolver.gd")

const DIGIT_CELL_WIDTH: int = 27
const DIGIT_CELL_HEIGHT: int = 36
const COLON_INDEX: int = 11

@export var digits_asset_id: String = "ui.battle.hud.timer.digits"
@export var digits_texture: Texture2D
@export var preview_text: String = "00:00"
@export var letter_spacing_px: float = 0.0

var _ui_asset_resolver = null
var _glyphs: Array[TextureRect] = []
var _current_text: String = ""


func _ready() -> void:
	_ensure_glyphs()
	_apply_text(preview_text)


func set_countdown_text(text_value: String) -> void:
	_apply_text(text_value)


func apply_countdown(remaining_tick_count: int, tick_rate: int) -> void:
	var safe_tick_rate: int = max(tick_rate, 1)
	var total_seconds: int = int(ceil(float(max(remaining_tick_count, 0)) / float(safe_tick_rate)))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	_apply_text("%02d:%02d" % [minutes, seconds])


func _ensure_glyphs() -> void:
	if _glyphs.size() == 5:
		return
	for child in get_children():
		child.queue_free()
	_glyphs.clear()
	for _i in range(5):
		var glyph := TextureRect.new()
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.custom_minimum_size = Vector2(DIGIT_CELL_WIDTH, DIGIT_CELL_HEIGHT)
		add_child(glyph)
		_glyphs.append(glyph)
	_layout_glyphs()


func _layout_glyphs() -> void:
	var x_cursor: float = 0.0
	for glyph in _glyphs:
		glyph.anchor_left = 0.0
		glyph.anchor_top = 0.0
		glyph.anchor_right = 0.0
		glyph.anchor_bottom = 0.0
		glyph.offset_left = x_cursor
		glyph.offset_top = 0.0
		glyph.offset_right = x_cursor + DIGIT_CELL_WIDTH
		glyph.offset_bottom = DIGIT_CELL_HEIGHT
		x_cursor += DIGIT_CELL_WIDTH + letter_spacing_px
	custom_minimum_size = Vector2(max(0.0, x_cursor - letter_spacing_px), DIGIT_CELL_HEIGHT)
	size = custom_minimum_size


func _apply_text(text_value: String) -> void:
	_ensure_glyphs()
	var normalized: String = text_value
	if normalized.is_empty():
		normalized = "00:00"
	if normalized.length() < 5:
		normalized = normalized.rpad(5, "0")
	if normalized.length() > 5:
		normalized = normalized.substr(0, 5)
	var source_texture: Texture2D = _resolve_digits_texture()
	if source_texture == null:
		return
	_current_text = normalized
	for i in range(_glyphs.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = source_texture
		atlas.region = Rect2(_resolve_symbol_index(_current_text[i]) * DIGIT_CELL_WIDTH, 0, DIGIT_CELL_WIDTH, DIGIT_CELL_HEIGHT)
		_glyphs[i].texture = atlas


func _resolve_symbol_index(symbol: String) -> int:
	if symbol == ":":
		return COLON_INDEX
	var digit := int(symbol.unicode_at(0) - "0".unicode_at(0))
	if digit >= 0 and digit <= 9:
		return digit
	return 0


func _resolve_digits_texture() -> Texture2D:
	if digits_texture != null:
		return digits_texture
	if _ui_asset_resolver == null:
		_ui_asset_resolver = UiAssetResolverScript.new()
		_ui_asset_resolver.configure(null, false)
	var loaded: Variant = _ui_asset_resolver.load_resource(digits_asset_id)
	if loaded is Texture2D:
		digits_texture = loaded
	return digits_texture
