@tool
class_name ScoreDigits
extends Control

const UiAssetResolverScript = preload("res://app/front/ui_resources/ui_asset_resolver.gd")

const DIGIT_CELL_WIDTH: int = 16
const DIGIT_CELL_HEIGHT: int = 18
const MAX_DIGITS: int = 3

@export var digits_asset_id: String = "ui.battle.hud.score.digits"
@export var digits_texture: Texture2D
@export var preview_value: int = 0
@export var letter_spacing_px: float = 0.0

var _ui_asset_resolver = null
var _glyphs: Array[TextureRect] = []
var _current_value: int = -1


func _ready() -> void:
	_ensure_glyphs()
	_apply_value(preview_value)


func set_value(value: int) -> void:
	_apply_value(value)


func set_visible_digits(visible: bool) -> void:
	for glyph in _glyphs:
		glyph.visible = visible


func _ensure_glyphs() -> void:
	if _glyphs.size() == MAX_DIGITS:
		return
	for child in get_children():
		child.queue_free()
	_glyphs.clear()
	for _i in range(MAX_DIGITS):
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


func _apply_value(value: int) -> void:
	_ensure_glyphs()
	if value == _current_value:
		return
	_current_value = value
	var source_texture: Texture2D = _resolve_digits_texture()
	if source_texture == null:
		return
	var text_value: String = str(clampi(value, 0, 999))
	# Right-align digits
	var padded: String = text_value.rpad(MAX_DIGITS, " ")
	for i in range(_glyphs.size()):
		var char_idx := padded.length() - MAX_DIGITS + i
		if char_idx < 0 or char_idx >= padded.length():
			_glyphs[i].texture = null
			_glyphs[i].visible = false
			continue
		var ch := padded[char_idx]
		if ch == " ":
			_glyphs[i].texture = null
			_glyphs[i].visible = false
			continue
		var digit := _resolve_digit_index(ch)
		var atlas := AtlasTexture.new()
		atlas.atlas = source_texture
		atlas.region = Rect2(digit * DIGIT_CELL_WIDTH, 0, DIGIT_CELL_WIDTH, DIGIT_CELL_HEIGHT)
		_glyphs[i].texture = atlas
		_glyphs[i].visible = true


func _resolve_digit_index(ch: String) -> int:
	var digit := int(ch.unicode_at(0) - "0".unicode_at(0))
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
