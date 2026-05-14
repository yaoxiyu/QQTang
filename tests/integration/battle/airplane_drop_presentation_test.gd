extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleDepthScript = preload("res://presentation/battle/battle_depth.gd")
const AirplaneActorViewScript = preload("res://presentation/battle/actors/airplane_actor_view.gd")
const BattleItemActorViewScript = preload("res://presentation/battle/actors/item_actor_view.gd")


func test_main() -> void:
	await _test_airplane_is_above_airborne_drop_and_ground_item()


func _test_airplane_is_above_airborne_drop_and_ground_item() -> void:
	var cell_size := 40.0
	var map_height := 13
	var airplane := qqt_add_child(AirplaneActorViewScript.new()) as AirplaneActorView
	airplane.configure(cell_size, map_height)
	airplane.update_position(7.0, 3)

	var item := qqt_add_child(BattleItemActorViewScript.new()) as BattleItemActorView
	var target_cell := Vector2i(3, 8)
	var from_world := Vector2(8.5 * cell_size, 2.5 * cell_size)
	var to_world := Vector2((target_cell.x + 0.5) * cell_size, (target_cell.y + 0.5) * cell_size)
	item.apply_view_state({
		"entity_id": 9901,
		"item_type": 0,
		"cell_size": cell_size,
		"cell": target_cell,
		"position": to_world,
		"scatter_from": from_world,
	})

	assert_true(airplane.z_index > item.z_index, "airplane should stay above airborne drop item")
	assert_eq(item.z_index, BattleDepthScript.item_airborne_z_from_world(from_world, to_world, cell_size), "airborne item z should use BattleDepth airborne band")

	item._on_scatter_landed()
	assert_eq(item.z_index, BattleDepthScript.item_ground_z(target_cell), "after landing, item should return to ground depth")
