extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")

@onready var loading_root: Control = $LoadingRoot
@onready var main_layout: VBoxContainer = $LoadingRoot/MainLayout
@onready var loading_label: Label = $LoadingRoot/MainLayout/LoadingLabel
@onready var manifest_summary_panel: PanelContainer = $LoadingRoot/MainLayout/ManifestSummaryPanel
@onready var map_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/MapSummaryLabel
@onready var rule_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/RuleSummaryLabel
@onready var mode_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/ModeSummaryLabel
@onready var item_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/ItemSummaryLabel
@onready var character_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/CharacterSummaryLabel
@onready var bubble_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/BubbleSummaryLabel
@onready var player_loadout_title_label: Label = $LoadingRoot/MainLayout/PlayerLoadoutTitleLabel
@onready var player_loading_list: VBoxContainer = $LoadingRoot/MainLayout/PlayerLoadingList
@onready var timeout_hint: Label = $LoadingRoot/MainLayout/TimeoutHint

var _app_runtime: Node = null
var _front_flow: Node = null
var _loading_started: bool = false
var _content_manifest_builder = BattleContentManifestBuilderScript.new()


func _ready() -> void:
	_configure_layout()
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_front_flow = _app_runtime.front_flow
	_restore_missing_start_config_from_adapter()
	_refresh_loading_view()
	call_deferred("_begin_loading")


func _configure_layout() -> void:
	loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout.anchor_right = 1.0
	main_layout.anchor_bottom = 1.0
	main_layout.offset_left = 64.0
	main_layout.offset_top = 64.0
	main_layout.offset_right = -64.0
	main_layout.offset_bottom = -64.0
	main_layout.add_theme_constant_override("separation", 18)
	player_loading_list.add_theme_constant_override("separation", 8)
	loading_label.text = "Loading Match..."
	player_loadout_title_label.text = "Players"
	timeout_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeout_hint.text = "Preparing runtime..."


func _refresh_loading_view() -> void:
	for child in player_loading_list.get_children():
		child.queue_free()

	var snapshot: RoomSnapshot = _app_runtime.current_room_snapshot if _app_runtime != null else null
	var config: BattleStartConfig = _app_runtime.current_start_config if _app_runtime != null else null
	var manifest := _resolve_loading_manifest(config)
	_apply_manifest_summary(manifest)
	if snapshot != null:
		for member in snapshot.sorted_members():
			var label := Label.new()
			label.text = _build_player_loading_text(member)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			player_loading_list.add_child(label)

	if config == null:
		timeout_hint.text = "Missing BattleStartConfig. Return to room and start again."
		return

	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	var map_display_name := String(ui_summary.get("map_display_name", config.map_id))
	loading_label.text = "Loading %s" % map_display_name
	timeout_hint.text = "Seed: %d\nPreparing battle scene..." % config.battle_seed


func _begin_loading() -> void:
	if _loading_started:
		return
	_loading_started = true
	_restore_missing_start_config_from_adapter()
	if _app_runtime == null or _app_runtime.current_start_config == null:
		return
	await get_tree().create_timer(0.75).timeout
	if _front_flow != null and _front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		_front_flow.on_match_loading_ready(_app_runtime.current_start_config)


func _restore_missing_start_config_from_adapter() -> void:
	if _app_runtime == null or _app_runtime.current_start_config != null or _app_runtime.battle_session_adapter == null:
		return
	var adapter_config: BattleStartConfig = _app_runtime.battle_session_adapter.get("start_config")
	if adapter_config == null:
		return
	_app_runtime.apply_canonical_start_config(adapter_config)


func _resolve_loading_manifest(config: BattleStartConfig) -> Dictionary:
	if _app_runtime != null and not _app_runtime.current_battle_content_manifest.is_empty():
		return _app_runtime.current_battle_content_manifest.duplicate(true)
	if config == null:
		return {}
	return _content_manifest_builder.build_for_start_config(config)


func _apply_manifest_summary(manifest: Dictionary) -> void:
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	var map_manifest: Dictionary = manifest.get("map", {})
	var rule_manifest: Dictionary = manifest.get("rule", {})
	var mode_manifest: Dictionary = manifest.get("mode", {})
	var characters: Array = manifest.get("characters", [])
	var bubbles: Array = manifest.get("bubbles", [])

	manifest_summary_panel.visible = not manifest.is_empty()
	map_summary_label.text = "地图: %s" % String(ui_summary.get("map_display_name", map_manifest.get("display_name", map_manifest.get("map_id", ""))))
	rule_summary_label.text = "规则: %s" % String(ui_summary.get("rule_display_name", rule_manifest.get("display_name", rule_manifest.get("rule_set_id", ""))))
	mode_summary_label.text = "模式: %s" % String(ui_summary.get("mode_display_name", mode_manifest.get("display_name", mode_manifest.get("mode_id", ""))))
	item_summary_label.text = String(ui_summary.get("item_brief", ""))
	character_summary_label.text = "角色: %s" % _build_manifest_character_summary(characters)
	bubble_summary_label.text = "泡泡: %s" % _build_manifest_bubble_summary(ui_summary, bubbles)


func _build_manifest_character_summary(characters: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for entry in characters:
		var display_name := String(entry.get("display_name", entry.get("character_id", "")))
		if display_name.is_empty() or names.has(display_name):
			continue
		names.append(display_name)
	return " / ".join(names) if not names.is_empty() else "-"


func _build_manifest_bubble_summary(ui_summary: Dictionary, bubbles: Array) -> String:
	var bubble_brief := String(ui_summary.get("bubble_brief", ""))
	if bubble_brief.begins_with("泡泡:"):
		return bubble_brief.trim_prefix("泡泡:")
	if not bubble_brief.is_empty():
		return bubble_brief
	var names: PackedStringArray = PackedStringArray()
	for entry in bubbles:
		var display_name := String(entry.get("display_name", entry.get("bubble_style_id", "")))
		if display_name.is_empty() or names.has(display_name):
			continue
		names.append(display_name)
	return " / ".join(names) if not names.is_empty() else "-"


func _build_player_loading_text(member: RoomMemberState) -> String:
	return "%s | slot:%d | ready:%s | char:%s | bubble:%s" % [
		member.player_name,
		member.slot_index,
		str(member.ready),
		_resolve_character_display_name(member.character_id),
		_resolve_bubble_display_name(member.bubble_style_id),
	]


func _resolve_character_display_name(character_id: String) -> String:
	if character_id.is_empty():
		return "-"
	var metadata := CharacterLoaderScript.load_character_metadata(character_id)
	return String(metadata.get("display_name", character_id))


func _resolve_bubble_display_name(bubble_style_id: String) -> String:
	if bubble_style_id.is_empty():
		return "-"
	var metadata := BubbleLoaderScript.load_metadata(bubble_style_id)
	return String(metadata.get("display_name", bubble_style_id))
