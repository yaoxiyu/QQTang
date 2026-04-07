extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")

@onready var status_label: Label = get_node_or_null("BootRoot/CenterPanel/MarginContainer/MainLayout/StatusLabel")
@onready var hint_label: Label = get_node_or_null("BootRoot/CenterPanel/MarginContainer/MainLayout/HintLabel")

var _app_runtime: Node = null


func _ready() -> void:
	if status_label != null:
		status_label.text = "Initializing Front Runtime..."
	if hint_label != null:
		hint_label.text = "Boot scene only decides login or lobby."
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	call_deferred("_decide_next_flow")


func _decide_next_flow() -> void:
	if _app_runtime == null:
		_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if _app_runtime == null or not _app_runtime.is_inside_tree() or _app_runtime.front_flow == null:
		call_deferred("_decide_next_flow")
		return
	var settings = _app_runtime.front_settings_state
	var profile = _app_runtime.player_profile_state
	var should_enter_lobby := false
	if settings != null and profile != null:
		should_enter_lobby = bool(settings.remember_profile) \
			and bool(settings.auto_enter_lobby) \
			and not String(profile.profile_id).strip_edges().is_empty() \
			and not String(profile.nickname).strip_edges().is_empty()
	if should_enter_lobby:
		_app_runtime.front_flow.enter_lobby()
		return
	_app_runtime.front_flow.enter_login()
