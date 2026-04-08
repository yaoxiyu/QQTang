extends SceneTree

var _failed := false
var _test_node: Node = null
var _finished := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("test_runner: missing script path")
		quit(2)
		return

	var script_path := String(args[0])
	var script := load(script_path)
	if script == null:
		push_error("test_runner: failed to load %s" % script_path)
		quit(2)
		return

	var node = script.new()
	if node == null:
		push_error("test_runner: failed to instantiate %s" % script_path)
		quit(2)
		return
	if not (node is Node):
		push_error("test_runner: %s must inherit Node" % script_path)
		quit(2)
		return

	_test_node = node
	root.add_child(_test_node)
	if _test_node.has_signal("test_finished"):
		_test_node.test_finished.connect(_finish, CONNECT_ONE_SHOT)
	else:
		call_deferred("_finish")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	call_deferred("_cleanup_and_quit")


func _cleanup_and_quit() -> void:
	if _test_node != null and is_instance_valid(_test_node):
		if _test_node.get_parent() != null:
			_test_node.get_parent().remove_child(_test_node)
		_test_node.free()
	await process_frame
	await process_frame
	quit(0 if not _failed else 1)
