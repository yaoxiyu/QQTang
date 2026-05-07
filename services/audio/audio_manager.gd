extends Node

const AudioCatalogScript = preload("res://content/audio/catalog/audio_catalog.gd")
const AudioTypesScript = preload("res://services/audio/audio_types.gd")
const SFX_POOL_SIZE := 16

var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_player: AudioStreamPlayer
var _inactive_bgm_player: AudioStreamPlayer
var _current_bgm_id: String = ""
var _bgm_tween: Tween

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

var _ui_player: AudioStreamPlayer

var _stream_cache: Dictionary = {}
var _muted: bool = false
var _master_volume_db: float = 0.0


func _ready() -> void:
	_create_players()


func _create_players() -> void:
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name = "BGMA"
	_bgm_player_a.bus = "BGM"
	_bgm_player_a.process_mode = PROCESS_MODE_ALWAYS
	add_child(_bgm_player_a)

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name = "BGMB"
	_bgm_player_b.bus = "BGM"
	_bgm_player_b.process_mode = PROCESS_MODE_ALWAYS
	add_child(_bgm_player_b)

	_active_bgm_player = _bgm_player_a
	_inactive_bgm_player = _bgm_player_b

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = "UI"
	add_child(_ui_player)


func play_bgm(audio_id: String, fade_in: float = 0.5) -> void:
	if _current_bgm_id == audio_id and _active_bgm_player.playing:
		return

	var resolved := AudioCatalogScript.resolve_alias(audio_id)
	if resolved == null:
		push_warning("AudioManager: BGM not found: %s" % audio_id)
		return

	var stream := _load_stream(resolved.audio_resource_path)
	if stream == null:
		return

	_stop_tween()

	if _active_bgm_player.playing:
		var swap := _inactive_bgm_player
		_inactive_bgm_player = _active_bgm_player
		_active_bgm_player = swap

	if _active_bgm_player.playing:
		var fade_out_player := _active_bgm_player
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(fade_out_player, "volume_db", -80.0, fade_in * 0.5)
		_bgm_tween.tween_callback(func(): fade_out_player.stop())

	_active_bgm_player = _inactive_bgm_player

	_active_bgm_player.stream = stream
	_active_bgm_player.volume_db = -80.0
	_active_bgm_player.play()

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_active_bgm_player, "volume_db", 0.0, fade_in)

	_current_bgm_id = audio_id


func stop_bgm(fade_out: float = 0.5) -> void:
	_stop_tween()

	if _active_bgm_player.playing:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_active_bgm_player, "volume_db", -80.0, fade_out)
		_bgm_tween.tween_callback(func(): _active_bgm_player.stop())
	_current_bgm_id = ""


func crossfade_bgm(audio_id: String, duration: float = 1.0) -> void:
	play_bgm(audio_id, duration)


func is_bgm_playing() -> bool:
	return _active_bgm_player.playing


func get_current_bgm_id() -> String:
	return _current_bgm_id


func play_sfx(audio_id: String, volume_offset_db: float = 0.0) -> void:
	if _muted:
		return

	var resolved := AudioCatalogScript.resolve_alias(audio_id)
	if resolved == null:
		push_warning("AudioManager: SFX not found: %s" % audio_id)
		return

	var stream := _load_stream(resolved.audio_resource_path)
	if stream == null:
		return

	var player := _acquire_sfx_player()
	var bus: String = resolved.bus
	if not bus.is_empty() and bus != "SFX":
		player.bus = bus
	else:
		player.bus = "SFX"

	player.stream = stream
	player.volume_db = volume_offset_db
	player.play()


func play_sfx_at(audio_id: String, position: Vector2, volume_offset_db: float = 0.0) -> void:
	if _muted:
		return

	var resolved := AudioCatalogScript.resolve_alias(audio_id)
	if resolved == null:
		push_warning("AudioManager: SFX not found: %s" % audio_id)
		return

	var stream := _load_stream(resolved.audio_resource_path)
	if stream == null:
		return

	var player := _acquire_sfx_player()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume_offset_db
	player.global_position = position
	player.play()


func play_ui_sfx(audio_id: String) -> void:
	if _muted:
		return

	var resolved := AudioCatalogScript.resolve_alias(audio_id)
	if resolved == null:
		push_warning("AudioManager: UI SFX not found: %s" % audio_id)
		return

	var stream := _load_stream(resolved.audio_resource_path)
	if stream == null:
		return

	_ui_player.stream = stream
	_ui_player.volume_db = 0.0
	_ui_player.play()


func set_bus_volume_db(bus: int, volume_db: float) -> void:
	var bus_name: String = AudioTypesScript.BUS_NAMES.get(bus, "Master")
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func get_bus_volume_db(bus: int) -> float:
	var bus_name: String = AudioTypesScript.BUS_NAMES.get(bus, "Master")
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return AudioServer.get_bus_volume_db(bus_index)
	return 0.0


func set_master_volume_db(volume_db: float) -> void:
	_master_volume_db = volume_db
	set_bus_volume_db(AudioTypesScript.Bus.MASTER, volume_db)


func set_muted(muted: bool) -> void:
	_muted = muted
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func preload_category(category: int) -> void:
	var category_str := _category_to_string(category)
	if category_str.is_empty():
		return
	var defs := AudioCatalogScript.get_by_category(category_str)
	for def in defs:
		if not _stream_cache.has(def.audio_resource_path):
			var stream := load(def.audio_resource_path)
			if stream != null:
				_stream_cache[def.audio_resource_path] = stream


func preload_battle_sfx() -> void:
	preload_category(AudioTypesScript.Category.SFX_BATTLE)


func preload_ui_sfx() -> void:
	preload_category(AudioTypesScript.Category.SFX_UI)


func _load_stream(path: String) -> Resource:
	if path.is_empty():
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream := load(path)
	if stream != null:
		_stream_cache[path] = stream
	return stream


func _acquire_sfx_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	return player


func _stop_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null


func _category_to_string(category: int) -> String:
	match category:
		AudioTypesScript.Category.BGM_MAP: return "BGM_MAP"
		AudioTypesScript.Category.BGM_SCENE: return "BGM_SCENE"
		AudioTypesScript.Category.BGM_RESULT: return "BGM_RESULT"
		AudioTypesScript.Category.BGM_EVENT: return "BGM_EVENT"
		AudioTypesScript.Category.SFX_BATTLE: return "SFX_BATTLE"
		AudioTypesScript.Category.SFX_UI: return "SFX_UI"
		AudioTypesScript.Category.SFX_ITEM: return "SFX_ITEM"
		AudioTypesScript.Category.SFX_VOICE: return "SFX_VOICE"
		AudioTypesScript.Category.SFX_EVENT: return "SFX_EVENT"
		AudioTypesScript.Category.SFX_NUMBERED_BATTLE: return "SFX_NUMBERED_BATTLE"
		AudioTypesScript.Category.SFX_NUMBERED_SHORT: return "SFX_NUMBERED_SHORT"
		AudioTypesScript.Category.SFX_NUMBERED_EXTENDED: return "SFX_NUMBERED_EXTENDED"
		AudioTypesScript.Category.SFX_NUMBERED_STEREO: return "SFX_NUMBERED_STEREO"
		AudioTypesScript.Category.SFX_OR_STINGER_NUMBERED: return "SFX_OR_STINGER_NUMBERED"
		_: return ""
