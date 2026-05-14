extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleDepthScript = preload("res://presentation/battle/battle_depth.gd")
const BattleItemActorViewScript = preload("res://presentation/battle/actors/item_actor_view.gd")


func test_main() -> void:
	await _test_airborne_item_uses_battle_depth_band()
	await _test_airborne_item_lands_back_to_ground_band()
	await _test_stale_scatter_from_does_not_restart_airborne_animation()


func _test_airborne_item_uses_battle_depth_band() -> void:
	var view := qqt_add_child(BattleItemActorViewScript.new()) as BattleItemActorView
	var cell_size := 40.0
	var from_world := Vector2(6.5 * cell_size, 2.5 * cell_size)
	var to_world := Vector2(2.5 * cell_size, 7.5 * cell_size)
	view.apply_view_state({
		"entity_id": 801,
		"item_type": 0,
		"cell_size": cell_size,
		"cell": Vector2i(2, 7),
		"position": to_world,
		"scatter_from": from_world,
	})
	var expected_airborne_z := BattleDepthScript.item_airborne_z_from_world(from_world, to_world, cell_size)
	assert_eq(view.z_index, expected_airborne_z, "scatter flight z should come from BattleDepth airborne api")


func _test_airborne_item_lands_back_to_ground_band() -> void:
	var view := qqt_add_child(BattleItemActorViewScript.new()) as BattleItemActorView
	var cell_size := 40.0
	var target_cell := Vector2i(3, 4)
	var from_world := Vector2(7.5 * cell_size, 1.5 * cell_size)
	var to_world := Vector2((target_cell.x + 0.5) * cell_size, (target_cell.y + 0.5) * cell_size)
	view.apply_view_state({
		"entity_id": 802,
		"item_type": 0,
		"cell_size": cell_size,
		"cell": target_cell,
		"position": to_world,
		"scatter_from": from_world,
	})
	view._on_scatter_landed()
	assert_eq(view.z_index, BattleDepthScript.item_ground_z(target_cell), "item should return to ground item depth after scatter landing")


func _test_stale_scatter_from_does_not_restart_airborne_animation() -> void:
	var view := qqt_add_child(BattleItemActorViewScript.new()) as BattleItemActorView
	var cell_size := 40.0
	var target_cell := Vector2i(4, 5)
	var from_world := Vector2(10.5 * cell_size, 2.5 * cell_size)
	var to_world := Vector2((target_cell.x + 0.5) * cell_size, (target_cell.y + 0.5) * cell_size)
	view.apply_view_state({
		"entity_id": 803,
		"item_type": 0,
		"cell_size": cell_size,
		"cell": target_cell,
		"position": to_world,
		"scatter_from": from_world,
		"spawn_tick": 10,
		"pickup_delay_ticks": 1,
		"current_tick": 200,  # stale scatter_from from old snapshot
	})
	assert_eq(view.z_index, BattleDepthScript.item_ground_z(target_cell), "stale scatter_from should not replay airborne animation")
