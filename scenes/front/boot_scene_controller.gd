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
	if _app_runtime.auth_session_restore_use_case == null or not _app_runtime.auth_session_restore_use_case.has_method("restore_on_boot"):
		if status_label != null:
			status_label.text = "Auth session restore is unavailable."
		if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_login"):
			_app_runtime.front_flow.enter_login()
		return
	if status_label != null:
		status_label.text = "Restoring session..."
	var result: Dictionary = await _app_runtime.auth_session_restore_use_case.restore_on_boot()
	var next_route := String(result.get("next_route", "login"))
	if next_route == "lobby":
		if status_label != null:
			status_label.text = "Session restored."
		_app_runtime.front_flow.enter_lobby()
		return
	if next_route == "error":
		if status_label != null:
			status_label.text = String(result.get("user_message", "Boot failed"))
		if hint_label != null:
			hint_label.text = String(result.get("error_code", "BOOT_ERROR"))
		if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_login"):
			_app_runtime.front_flow.enter_login()
		return
	if status_label != null:
		status_label.text = "No valid session."
	_app_runtime.front_flow.enter_login()
