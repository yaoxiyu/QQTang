extends "res://tests/gut/base/qqt_unit_test.gd"

const ChannelVisualPolicyScript = preload("res://presentation/battle/policy/channel_visual_policy.gd")


func test_main() -> void:
	_test_player_hide_body_inside_channel_center()
	_test_bubble_hide_respects_default_channel_policy()
	_test_player_depth_prefers_local_surface_occlusion()
	_test_player_depth_fallbacks_to_row_max_when_local_missing()


func _test_player_hide_body_inside_channel_center() -> void:
	var channel_map := {Vector2i(3, 2): 15}
	var cell_size := 40.0
	var center := Vector2((3.0 + 0.5) * cell_size, (2.0 + 0.5) * cell_size)
	var hidden := ChannelVisualPolicyScript.resolve_player_body_hidden(center, cell_size, channel_map)
	assert_true(hidden, "player body should hide near channel center")


func _test_bubble_hide_respects_default_channel_policy() -> void:
	var channel_map := {Vector2i(1, 1): 5}
	assert_true(
		ChannelVisualPolicyScript.resolve_bubble_hidden(Vector2i(1, 1), channel_map),
		"bubble should hide on channel cell by default policy"
	)
	assert_false(
		ChannelVisualPolicyScript.resolve_bubble_hidden(Vector2i(2, 1), channel_map),
		"bubble should remain visible outside channel cell"
	)


func _test_player_depth_prefers_local_surface_occlusion() -> void:
	var base_z := 220
	var player_cell := Vector2i(4, 4)
	var candidate_cells: Array[Vector2i] = [player_cell, Vector2i(4, 3)]
	var surface_occlusion := {
		Vector2i(4, 3): {
			"render_z": 333,
		}
	}
	var resolved := ChannelVisualPolicyScript.resolve_player_z(base_z, player_cell, candidate_cells, surface_occlusion, {})
	assert_eq(int(resolved.get("z", -1)), 334, "local surface occlusion should raise player depth to occluder+1")
	assert_eq(String(resolved.get("reason", "")), "surface_local", "reason should report local surface occlusion")


func _test_player_depth_fallbacks_to_row_max_when_local_missing() -> void:
	var base_z := 220
	var player_cell := Vector2i(4, 4)
	var row_fallback := {4: 260}
	var resolved := ChannelVisualPolicyScript.resolve_player_z(base_z, player_cell, [player_cell], {}, row_fallback)
	assert_eq(int(resolved.get("z", -1)), 261, "row fallback should still keep legacy compatibility")
	assert_eq(String(resolved.get("reason", "")), "surface_row_fallback", "reason should report fallback mode")
