extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	await _test_get_existing_does_not_create_runtime()
	await _test_scene_tree_keeps_single_app_root()
	test_finished.emit()


func _test_get_existing_does_not_create_runtime() -> void:
	var existing = AppRuntimeRootScript.get_existing(get_tree())
	_assert_true(existing == null, "get_existing returns null when runtime is missing")
	_assert_true(not get_tree().root.has_node("AppRoot"), "get_existing does not create AppRoot when missing")

	var root_child_count_before := get_tree().root.get_child_count()
	var second_lookup = AppRuntimeRootScript.get_existing(get_tree())
	_assert_true(second_lookup == null, "repeated get_existing still returns null without runtime")
	_assert_true(get_tree().root.get_child_count() == root_child_count_before, "get_existing does not change root child count")


func _test_scene_tree_keeps_single_app_root() -> void:
	var runtime_a = AppRuntimeRootScript.ensure_in_tree(get_tree())
	var runtime_b = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	var existing = AppRuntimeRootScript.get_existing(get_tree())

	_assert_true(runtime_a != null and runtime_b != null, "ensure_in_tree returns runtime on repeated calls")
	_assert_true(runtime_a == runtime_b and runtime_b == existing, "ensure_in_tree reuses existing runtime instance")
	_assert_true(_count_app_roots() == 1, "scene tree keeps a single AppRoot instance")

	if runtime_a != null:
		runtime_a.queue_free()
	await get_tree().process_frame


func _count_app_roots() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child != null and String(child.name) == "AppRoot":
			count += 1
	return count


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
