extends "res://tests/gut/base/qqt_unit_test.gd"

const BattlePlayerActorViewScript = preload("res://presentation/battle/actors/player_actor_view.gd")
const BattleDepthScript = preload("res://presentation/battle/battle_depth.gd")


func test_main() -> void:
	_test_next_row_surface_does_not_raise_player_depth()
	_test_mxn_surface_occupied_cell_can_raise_player_depth()


func _test_next_row_surface_does_not_raise_player_depth() -> void:
	var view := qqt_add_child(BattlePlayerActorViewScript.new()) as BattlePlayerActorView
	view.configure_surface_occlusion_by_cell({
		Vector2i(5, 6): {
			"render_z": 9999,
		}
	})
	view.configure_surface_row_priority_map({})
	var state := {
		"entity_id": 1001,
		"player_slot": 0,
		"alive": true,
		"facing": 1,
		"cell": Vector2i(5, 5),
		"offset": Vector2.ZERO,
		"cell_size": 40.0,
		"position": Vector2((5.0 + 0.5) * 40.0, (5.0 + 0.5) * 40.0),
	}
	view.apply_view_state(state)
	var expected := BattleDepthScript.player_z(Vector2i(5, 5), 0, 0)
	assert_eq(view.z_index, expected, "next-row surface should not incorrectly raise current-row player depth")


func _test_mxn_surface_occupied_cell_can_raise_player_depth() -> void:
	var view := qqt_add_child(BattlePlayerActorViewScript.new()) as BattlePlayerActorView
	# Simulate a large MxN surface footprint already expanded to occupied cells.
	view.configure_surface_occlusion_by_cell({
		Vector2i(4, 5): {"render_z": 600},
		Vector2i(5, 5): {"render_z": 600},
		Vector2i(6, 5): {"render_z": 600},
		Vector2i(4, 4): {"render_z": 600},
		Vector2i(5, 4): {"render_z": 600},
		Vector2i(6, 4): {"render_z": 600},
	})
	view.configure_surface_row_priority_map({})
	var state := {
		"entity_id": 1002,
		"player_slot": 0,
		"alive": true,
		"facing": 1,
		"cell": Vector2i(5, 5),
		"offset": Vector2.ZERO,
		"cell_size": 40.0,
		"position": Vector2((5.0 + 0.5) * 40.0, (5.0 + 0.5) * 40.0),
	}
	view.apply_view_state(state)
	assert_eq(view.z_index, 601, "MxN surface occupied cell should raise player depth by local occlusion rule")
