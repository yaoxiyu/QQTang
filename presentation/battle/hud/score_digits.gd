@tool
class_name ScoreDigits
extends Control

const UiAssetResolverScript = preload("res://app/front/ui_resources/ui_asset_resolver.gd")
const MISC_ANIM_BASE_DIR := "res://external/assets/derived/assets/animation/misc/"
const SCORE_BG_DIR := MISC_ANIM_BASE_DIR + "misc350_stand"
const SCORE_DIGIT_ACEG_DIR := MISC_ANIM_BASE_DIR + "misc351_stand"
const SCORE_DIGIT_BDFH_DIR := MISC_ANIM_BASE_DIR + "misc353_stand"
const SCORE_BG_NORMAL_FRAME := 0
const SCORE_BG_LEADING_FRAME := 1
const DIGIT_BASE_SCALE := 0.82
const DIGIT_HORIZONTAL_PADDING := 2.0
const DIGIT_OPTICAL_OFFSET_X := 0.0
const DIGIT_OPTICAL_OFFSET_Y := 2.0

const MAX_DIGITS: int = 3

@export var digits_asset_id: String = "ui.battle.hud.score.digits"
@export var digits_texture: Texture2D
@export var preview_value: int = 0:
	set(v):
		preview_value = v
		if Engine.is_editor_hint():
			_refresh_editor_preview()
@export var letter_spacing_px: float = 0.0:
	set(v):
		letter_spacing_px = v
		if Engine.is_editor_hint():
			_refresh_editor_preview()
@export var preview_slot_index: int = 0:
	set(v):
		preview_slot_index = v
		if Engine.is_editor_hint():
			_refresh_editor_preview()

var _ui_asset_resolver = null
var _background: TextureRect = null
var _glyphs: Array[TextureRect] = []
var _current_value: int = -1
var _slot_index: int = 0
var _all_teams_tied: bool = true
var _team_is_leading: bool = false
var _current_digit_style: String = "aceg"

static var _bg_frames_cache: Array[Texture2D] = []
static var _digit_aceg_cache: Array[Texture2D] = []
static var _digit_bdfh_cache: Array[Texture2D] = []
static var _digit_used_rect_cache: Dictionary = {}


func _ready() -> void:
	_slot_index = preview_slot_index if Engine.is_editor_hint() else _infer_slot_index_from_node_name()
	_current_digit_style = "aceg" if Engine.is_editor_hint() else _resolve_digit_style_by_slot(_slot_index)
	_ensure_glyphs()
	_apply_background_style()
	_apply_value(preview_value)
	if Engine.is_editor_hint():
		call_deferred("_refresh_editor_preview")


func set_value(value: int) -> void:
	_apply_value(value)


func set_visible_digits(visible: bool) -> void:
	if _background != null:
		_background.visible = visible
	for glyph in _glyphs:
		glyph.visible = visible


func _ensure_glyphs() -> void:
	if _glyphs.size() == MAX_DIGITS:
		return
	for child in get_children():
		child.queue_free()
	_glyphs.clear()
	_background = TextureRect.new()
	_background.name = "ScoreBackground"
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	for _i in range(MAX_DIGITS):
		var glyph := TextureRect.new()
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glyph)
		_glyphs.append(glyph)
	_layout_glyphs()


func _layout_glyphs() -> void:
	var bg_texture := _resolve_background_texture()
	var bg_size := Vector2(48.0, 24.0)
	if bg_texture != null:
		bg_size = bg_texture.get_size()
	if _background != null:
		_background.anchor_left = 0.0
		_background.anchor_top = 0.0
		_background.anchor_right = 0.0
		_background.anchor_bottom = 0.0
		_background.offset_left = 0.0
		_background.offset_top = 0.0
		_background.offset_right = bg_size.x
		_background.offset_bottom = bg_size.y

	var sample_digit := _resolve_digit_texture(0)
	var digit_size := Vector2(16.0, 18.0)
	if sample_digit != null:
		digit_size = sample_digit.get_size()
	var scaled_digit_size: Vector2 = digit_size * DIGIT_BASE_SCALE
	var total_scaled_width: float = scaled_digit_size.x * float(MAX_DIGITS) + letter_spacing_px * float(MAX_DIGITS - 1)
	var x_cursor: float = (bg_size.x - total_scaled_width) * 0.5
	var y_top: float = (bg_size.y - scaled_digit_size.y) * 0.5
	for glyph in _glyphs:
		glyph.anchor_left = 0.0
		glyph.anchor_top = 0.0
		glyph.anchor_right = 0.0
		glyph.anchor_bottom = 0.0
		glyph.offset_left = x_cursor
		glyph.offset_top = y_top
		glyph.offset_right = x_cursor + scaled_digit_size.x
		glyph.offset_bottom = y_top + scaled_digit_size.y
		x_cursor += scaled_digit_size.x + letter_spacing_px
	custom_minimum_size = bg_size
	size = custom_minimum_size


func _apply_value(value: int) -> void:
	_ensure_glyphs()
	if value == _current_value:
		return
	_current_value = value
	_apply_background_style()
	var text_value: String = str(clampi(value, 0, 999))
	var digit_count: int = mini(text_value.length(), MAX_DIGITS)
	var bg_texture := _resolve_background_texture()
	var bg_size := Vector2(48.0, 24.0)
	if bg_texture != null:
		bg_size = bg_texture.get_size()
	var digit_regions: Array[Rect2] = []
	var digit_textures: Array[Texture2D] = []
	var raw_max_height: float = 0.0
	for i in range(digit_count):
		var ch := text_value.substr(i, 1)
		var digit := _resolve_digit_index(ch)
		var tex := _resolve_digit_texture(digit)
		var region := _resolve_digit_used_region(tex)
		digit_textures.append(tex)
		digit_regions.append(region)
		raw_max_height = maxf(raw_max_height, region.size.y)
	if raw_max_height <= 0.0:
		raw_max_height = 1.0
	var normalized_total_width: float = 0.0
	for i in range(digit_regions.size()):
		var region: Rect2 = digit_regions[i]
		var h := maxf(region.size.y, 1.0)
		normalized_total_width += region.size.x * (raw_max_height / h)
		if i < digit_regions.size() - 1:
			normalized_total_width += letter_spacing_px
	if normalized_total_width <= 0.0:
		normalized_total_width = 1.0
	var width_budget: float = maxf(1.0, bg_size.x - DIGIT_HORIZONTAL_PADDING * 2.0)
	var height_budget: float = maxf(1.0, bg_size.y - 2.0)
	var scale_factor: float = minf(DIGIT_BASE_SCALE, minf(width_budget / normalized_total_width, height_budget / raw_max_height))
	var total_width: float = normalized_total_width * scale_factor
	var start_x: float = (bg_size.x - total_width) * 0.5 + DIGIT_OPTICAL_OFFSET_X
	var y_top: float = (bg_size.y - raw_max_height * scale_factor) * 0.5 + DIGIT_OPTICAL_OFFSET_Y
	var x_cursor: float = start_x
	for i in range(_glyphs.size()):
		if i >= digit_count:
			_glyphs[i].texture = null
			_glyphs[i].visible = false
			continue
		var tex := digit_textures[i]
		var region := digit_regions[i]
		if tex == null:
			_glyphs[i].texture = null
			_glyphs[i].visible = false
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		_glyphs[i].texture = atlas
		_glyphs[i].visible = true
		var region_h := maxf(region.size.y, 1.0)
		var glyph_w: float = region.size.x * (raw_max_height / region_h) * scale_factor
		var glyph_h: float = region.size.y * scale_factor
		_glyphs[i].anchor_left = 0.0
		_glyphs[i].anchor_top = 0.0
		_glyphs[i].anchor_right = 0.0
		_glyphs[i].anchor_bottom = 0.0
		_glyphs[i].offset_left = roundf(x_cursor)
		_glyphs[i].offset_top = roundf(y_top)
		_glyphs[i].offset_right = roundf(x_cursor + glyph_w)
		_glyphs[i].offset_bottom = roundf(y_top + raw_max_height * scale_factor)
		x_cursor += glyph_w + letter_spacing_px


func _resolve_digit_index(ch: String) -> int:
	var digit := int(ch.unicode_at(0) - "0".unicode_at(0))
	if digit >= 0 and digit <= 9:
		return digit
	return 0


func set_slot_index(slot_0: int) -> void:
	_slot_index = max(slot_0, 0)
	_current_digit_style = _resolve_digit_style_by_slot(_slot_index)
	_current_value = -1
	_apply_value(preview_value if Engine.is_editor_hint() else 0)


func set_team_score_style(all_teams_tied: bool, team_is_leading: bool) -> void:
	_all_teams_tied = all_teams_tied
	_team_is_leading = team_is_leading
	_apply_background_style()


func _apply_background_style() -> void:
	if _background == null:
		return
	_background.texture = _resolve_background_texture()


func _resolve_background_texture() -> Texture2D:
	var frames := _load_misc_frames_cached(SCORE_BG_DIR, _bg_frames_cache)
	if frames.is_empty():
		return null
	if _all_teams_tied:
		return frames[min(SCORE_BG_NORMAL_FRAME, frames.size() - 1)]
	if _team_is_leading:
		return frames[min(SCORE_BG_LEADING_FRAME, frames.size() - 1)]
	return frames[min(SCORE_BG_NORMAL_FRAME, frames.size() - 1)]


func _resolve_digit_texture(digit: int) -> Texture2D:
	var safe_digit := clampi(digit, 0, 9)
	var frames: Array[Texture2D] = []
	if _current_digit_style == "aceg":
		frames = _load_misc_frames_cached(SCORE_DIGIT_ACEG_DIR, _digit_aceg_cache)
	else:
		frames = _load_misc_frames_cached(SCORE_DIGIT_BDFH_DIR, _digit_bdfh_cache)
	if frames.is_empty():
		return _resolve_legacy_digit_texture(safe_digit)
	if safe_digit >= frames.size():
		return frames[0]
	return frames[safe_digit]


func _resolve_digit_style_by_slot(slot_0: int) -> String:
	return "aceg" if slot_0 % 2 == 0 else "bdfh"


func _infer_slot_index_from_node_name() -> int:
	var nm := String(name)
	var digits := ""
	for i in range(nm.length()):
		var ch := nm.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits.is_empty():
		return 0
	return max(int(digits) - 1, 0)


func _load_misc_frames_cached(anim_dir: String, cache: Array[Texture2D]) -> Array[Texture2D]:
	if not cache.is_empty():
		return cache
	var dir := DirAccess.open(anim_dir)
	if dir == null:
		return cache
	var frame_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
			frame_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	frame_files.sort()
	for frame_file in frame_files:
		var texture := load(anim_dir + "/" + frame_file) as Texture2D
		if texture != null:
			cache.append(texture)
	return cache


func _resolve_legacy_digit_texture(digit: int) -> Texture2D:
	var source_texture: Texture2D = _resolve_digits_texture()
	if source_texture == null:
		return null
	var sample_width := 16
	var sample_height := 18
	if source_texture.get_width() >= 100:
		sample_width = int(source_texture.get_width() / 10)
		sample_height = source_texture.get_height()
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = Rect2(digit * sample_width, 0, sample_width, sample_height)
	return atlas


func _resolve_digit_used_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2(0, 0, 1, 1)
	var cache_key := "%s|%dx%d" % [String(texture.resource_path), texture.get_width(), texture.get_height()]
	if _digit_used_rect_cache.has(cache_key):
		return _digit_used_rect_cache[cache_key]
	var region := Rect2(0, 0, texture.get_width(), texture.get_height())
	var image := texture.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			# Keep full frame height to guarantee same rendered height across digits.
			# Only trim horizontal transparent margins for better centering.
			region = Rect2(float(used.position.x), 0.0, float(used.size.x), float(texture.get_height()))
	_digit_used_rect_cache[cache_key] = region
	return region


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


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_slot_index = preview_slot_index
	_current_digit_style = "aceg"
	_all_teams_tied = true
	_team_is_leading = false
	_current_value = -1
	_ensure_glyphs()
	_apply_background_style()
	_apply_value(preview_value)
