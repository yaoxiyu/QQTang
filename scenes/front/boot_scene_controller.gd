extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LogSystemInitializerScript = preload("res://app/logging/log_system_initializer.gd")

@onready var status_label: Label = get_node_or_null("BootRoot/CenterPanel/MarginContainer/MainLayout/StatusLabel")
@onready var hint_label: Label = get_node_or_null("BootRoot/CenterPanel/MarginContainer/MainLayout/HintLabel")

var _app_runtime: Node = null


func _ready() -> void:
	## 初始化客户端日志系统
	LogSystemInitializerScript.initialize_client()
	
	if status_label != null:
		status_label.text = "Initializing Front Runtime..."
	if hint_label != null:
		hint_label.text = "Boot scene only decides login or lobby."
	_bind_runtime()


func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if _app_runtime == null:
		if status_label != null:
			status_label.text = "Failed to create front runtime."
		return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready():
		_on_runtime_ready()
		return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_on_runtime_ready):
		_app_runtime.runtime_ready.connect(_on_runtime_ready, CONNECT_ONE_SHOT)


func _on_runtime_ready() -> void:
	if _app_runtime == null:
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
