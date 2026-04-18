extends "res://tests/gut/base/qqt_unit_test.gd"

const ExplosionHitEntry = preload("res://gameplay/simulation/explosion/explosion_hit_entry.gd")
const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")


func test_main() -> void:
	var ok := true
	ok = _test_player_key_is_stable() and ok
	ok = _test_block_key_ignores_entity_id() and ok
	ok = _test_different_targets_do_not_collide() and ok


func _test_player_key_is_stable() -> bool:
	var entry_a := _make_entry(ExplosionHitTypes.TargetType.PLAYER, 7, 4, 5)
	var entry_b := _make_entry(ExplosionHitTypes.TargetType.PLAYER, 7, 4, 5)
	var prefix := "explosion_hit_entry_test"
	var ok := true
	ok = qqt_check(entry_a.build_dedupe_key() == "player:7:4:5", "player dedupe key should use entity and cell", prefix) and ok
	ok = qqt_check(entry_a.build_dedupe_key() == entry_b.build_dedupe_key(), "same player hit should produce stable dedupe key", prefix) and ok
	return ok


func _test_block_key_ignores_entity_id() -> bool:
	var entry_a := _make_entry(ExplosionHitTypes.TargetType.BREAKABLE_BLOCK, 11, 8, 3)
	var entry_b := _make_entry(ExplosionHitTypes.TargetType.BREAKABLE_BLOCK, 99, 8, 3)
	var prefix := "explosion_hit_entry_test"
	var ok := true
	ok = qqt_check(entry_a.build_dedupe_key() == "block:8:3", "block dedupe key should only depend on cell", prefix) and ok
	ok = qqt_check(entry_a.build_dedupe_key() == entry_b.build_dedupe_key(), "block dedupe key should ignore placeholder entity id", prefix) and ok
	return ok


func _test_different_targets_do_not_collide() -> bool:
	var player_key := _make_entry(ExplosionHitTypes.TargetType.PLAYER, 1, 2, 3).build_dedupe_key()
	var item_key := _make_entry(ExplosionHitTypes.TargetType.ITEM, 1, 2, 3).build_dedupe_key()
	var bubble_key := _make_entry(ExplosionHitTypes.TargetType.BUBBLE, 1, 2, 3).build_dedupe_key()
	var prefix := "explosion_hit_entry_test"
	var ok := true
	ok = qqt_check(player_key != item_key, "player and item dedupe keys should not collide", prefix) and ok
	ok = qqt_check(player_key != bubble_key, "player and bubble dedupe keys should not collide", prefix) and ok
	ok = qqt_check(item_key != bubble_key, "item and bubble dedupe keys should not collide", prefix) and ok
	return ok


func _make_entry(target_type: int, target_entity_id: int, cell_x: int, cell_y: int) -> ExplosionHitEntry:
	var entry := ExplosionHitEntry.new()
	entry.target_type = target_type
	entry.target_entity_id = target_entity_id
	entry.target_cell_x = cell_x
	entry.target_cell_y = cell_y
	return entry

