class_name QQTGutTest
extends "res://addons/gut/test.gd"

const LogConfigScript = preload("res://app/logging/log_config.gd")
const LogManagerScript = preload("res://app/logging/log_manager.gd")
const LogLevelConstantsScript = preload("res://app/logging/log_types.gd")

var _qqt_owned_nodes: Array[Node] = []
var _qqt_log_initialized_by_test: bool = false


func before_each() -> void:
	_qqt_owned_nodes.clear()
	_initialize_test_logging()


func after_each() -> void:
	for index in range(_qqt_owned_nodes.size() - 1, -1, -1):
		qqt_detach_and_free(_qqt_owned_nodes[index])
	_qqt_owned_nodes.clear()
	if _qqt_log_initialized_by_test:
		LogManagerScript.on_exit()
		_qqt_log_initialized_by_test = false


func qqt_add_child(node: Node, parent: Node = null) -> Node:
	if node == null:
		return null
	var target_parent := parent if parent != null else get_tree().root
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	target_parent.add_child(node)
	_qqt_owned_nodes.append(node)
	return node


func qqt_detach_and_free(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_qqt_owned_nodes.erase(node)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func qqt_wait_frames(count: int = 1) -> void:
	var frame_count := maxi(count, 1)
	for _index in range(frame_count):
		await get_tree().process_frame


func assert_dict_has_key(dict: Dictionary, key, message: String = "") -> void:
	var msg := message
	if msg.is_empty():
		msg = "dictionary should contain key: %s" % String(key)
	assert_true(dict.has(key), msg)


func assert_dict_string(dict: Dictionary, key, expected: String, message: String = "") -> void:
	assert_dict_has_key(dict, key, message if not message.is_empty() else "dictionary missing key: %s" % String(key))
	var actual := String(dict.get(key, ""))
	var msg := message
	if msg.is_empty():
		msg = "dictionary key %s should equal expected string" % String(key)
	assert_eq(actual, expected, msg)


func qqt_check(condition: bool, message: String, _prefix: String = "") -> bool:
	assert_true(condition, message)
	return condition


func _initialize_test_logging() -> void:
	var script: Script = get_script()
	if script == null:
		return
	var script_path := String(script.resource_path)
	if script_path.begins_with("res://tests/unit/logging/"):
		return
	var config := LogConfigScript.new()
	config.console_enabled = false
	config.file_enabled = false
	config.min_level = LogLevelConstantsScript.Level.FATAL
	var err := LogManagerScript.initialize_with_config(config)
	_qqt_log_initialized_by_test = err == OK

