extends "res://tests/gut/base/qqt_integration_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const ClientRoomRuntimeScript = preload("res://network/runtime/room_client/client_room_runtime.gd")
const ENetBattleTransportScript = preload("res://network/transport/enet_battle_transport.gd")



func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	var ok := true
	ok = await _test_transport_callbacks_do_not_create_runtime_when_missing() and ok
	ok = await _test_transport_callbacks_reuse_existing_runtime_without_creating_second_root() and ok


func _test_transport_callbacks_do_not_create_runtime_when_missing() -> bool:
	var existing_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if existing_runtime != null and is_instance_valid(existing_runtime):
		existing_runtime.queue_free()
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
	ok = qqt_check(AppRuntimeRootScript.get_existing(get_tree()) == null, "transport callbacks should not create AppRoot when runtime is missing", prefix) and ok
	ok = qqt_check(_count_app_roots() == 0, "scene tree should keep zero AppRoot instances when callbacks run without runtime", prefix) and ok

	if is_instance_valid(client_runtime):
		client_runtime.queue_free()
	await get_tree().process_frame
	return ok

func _test_transport_callbacks_reuse_existing_runtime_without_creating_second_root() -> bool:
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	if runtime == null:
		return qqt_check(false, "runtime bootstrap should succeed before transport callback reuse check", "client_room_runtime_no_runtime_creation_test")
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
	ok = qqt_check(runtime == AppRuntimeRootScript.get_existing(get_tree()), "transport callbacks should reuse the existing AppRoot", prefix) and ok
	ok = qqt_check(_count_app_roots() == 1, "transport callbacks should not create a second AppRoot", prefix) and ok
	ok = qqt_check(int(runtime.local_peer_id) == 1, "disconnect callback should restore local peer id on the existing runtime", prefix) and ok

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


