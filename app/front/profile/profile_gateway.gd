class_name ProfileGateway
extends RefCounted


func fetch_my_profile(access_token: String) -> Dictionary:
	await _yield_once()
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "ProfileGateway.fetch_my_profile not implemented",
	}


func _yield_once() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
