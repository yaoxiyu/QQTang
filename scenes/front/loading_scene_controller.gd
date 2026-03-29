extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")

@onready var loading_root: Control = $LoadingRoot
@onready var main_layout: VBoxContainer = $LoadingRoot/MainLayout
@onready var loading_label: Label = $LoadingRoot/MainLayout/LoadingLabel
@onready var player_loading_list: VBoxContainer = $LoadingRoot/MainLayout/PlayerLoadingList
@onready var timeout_hint: Label = $LoadingRoot/MainLayout/TimeoutHint

var _app_runtime: Node = null
var _front_flow: Node = null
var _loading_started: bool = false


func _ready() -> void:
	_configure_layout()
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_front_flow = _app_runtime.front_flow
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
	timeout_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeout_hint.text = "Preparing runtime..."


func _refresh_loading_view() -> void:
	for child in player_loading_list.get_children():
		child.queue_free()

	var snapshot: RoomSnapshot = _app_runtime.current_room_snapshot if _app_runtime != null else null
	var config: BattleStartConfig = _app_runtime.current_start_config if _app_runtime != null else null
	if snapshot != null:
		for member in snapshot.sorted_members():
			var label := Label.new()
			label.text = "%s  slot:%d  ready:%s" % [member.player_name, member.slot_index, str(member.ready)]
			player_loading_list.add_child(label)

	if config == null:
		timeout_hint.text = "Missing BattleStartConfig. Return to room and start again."
		return

	loading_label.text = "Loading %s" % config.map_id
	timeout_hint.text = "Map: %s\nRule: %s\nSeed: %d\nPreparing battle scene..." % [config.map_id, config.rule_set_id, config.seed]


func _begin_loading() -> void:
	if _loading_started:
		return
	_loading_started = true
	if _app_runtime == null or _app_runtime.current_start_config == null:
		return
	await get_tree().create_timer(0.75).timeout
	if _front_flow != null and _front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		_front_flow.on_match_loading_ready(_app_runtime.current_start_config)