extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const ClientRoomRuntimeScript = preload("res://network/runtime/client_room_runtime.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var ok := true
	ok = await _test_transport_callbacks_do_not_create_runtime_when_missing() and ok
	ok = await _test_transport_callbacks_reuse_existing_runtime_without_creating_second_root() and ok
	if ok:
		print("client_room_runtime_no_runtime_creation_test: PASS")
	test_finished.emit()


func _test_transport_callbacks_do_not_create_runtime_when_missing() -> bool:
	var client_runtime := ClientRoomRuntimeScript.new()
	add_child(client_runtime)
	client_runtime._transport = ENetBattleTransportScript.new()
	client_runtime.add_child(client_runtime._transport)

	client_runtime.call("_on_transport_connected")
	client_runtime.call("_on_transport_disconnected")

	var prefix := "client_room_runtime_no_runtime_creation_test"
	var ok := true
	ok = TestAssert.is_true(AppRuntimeRootScript.get_existing(get_tree()) == null, "transport callbacks should not create AppRoot when runtime is missing", prefix) and ok
	ok = TestAssert.is_true(_count_app_roots() == 0, "scene tree should keep zero AppRoot instances when callbacks run without runtime", prefix) and ok

	if is_instance_valid(client_runtime):
		client_runtime.queue_free()
	await get_tree().process_frame
	return ok

func _test_transport_callbacks_reuse_existing_runtime_without_creating_second_root() -> bool:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if runtime == null:
		return TestAssert.is_true(false, "runtime bootstrap should succeed before transport callback reuse check", "client_room_runtime_no_runtime_creation_test")
	await get_tree().process_frame
	await get_tree().process_frame

	var client_runtime := ClientRoomRuntimeScript.new()
	add_child(client_runtime)
	client_runtime._transport = ENetBattleTransportScript.new()
	client_runtime.add_child(client_runtime._transport)

	client_runtime.call("_on_transport_connected")
	client_runtime.call("_on_transport_disconnected")

	var prefix := "client_room_runtime_no_runtime_creation_test"
	var ok := true
	ok = TestAssert.is_true(runtime == AppRuntimeRootScript.get_existing(get_tree()), "transport callbacks should reuse the existing AppRoot", prefix) and ok
	ok = TestAssert.is_true(_count_app_roots() == 1, "transport callbacks should not create a second AppRoot", prefix) and ok
	ok = TestAssert.is_true(int(runtime.local_peer_id) == 1, "disconnect callback should restore local peer id on the existing runtime", prefix) and ok

	if is_instance_valid(client_runtime):
		client_runtime.queue_free()
	if is_instance_valid(runtime):
		runtime.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return ok


func _count_app_roots() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child != null and String(child.name) == "AppRoot":
			count += 1
	return count
