extends ContentCsvGeneratorBase
class_name GenerateBattleItems

const INPUT_CSV_PATH := "res://content_source/csv/battle_items/battle_item.csv"
const OUTPUT_DIR := "res://content/items/data/battle_item/"
const BattleItemDefinitionScript = preload("res://content/items/defs/battle_item_definition.gd")

const DERIVED_ANIM_ROOT := "res://external/assets/derived/assets/animation/items"


func generate() -> void:
	var rows := read_csv_rows(INPUT_CSV_PATH)
	if rows.is_empty():
		push_error("battle_item.csv has no data rows")
		return

	var reader := ContentCsvReaderScript.new()

	for row in rows:
		var battle_item_id := reader.require_string(row, "battle_item_id")
		if battle_item_id.is_empty():
			continue

		var def := BattleItemDefinitionScript.new()
		def.battle_item_id = battle_item_id
		def.item_type = reader.parse_int(row.get("item_type", "0"))
		def.display_name = reader.optional_string(row, "display_name", "Item %s" % battle_item_id)
		def.description = reader.optional_string(row, "description", "")
		def.rarity = reader.optional_string(row, "rarity", "common")
		def.stand_source = reader.optional_string(row, "stand_source", "")
		def.trigger_source = reader.optional_string(row, "trigger_source", "")
		def.enabled = reader.parse_bool(row.get("enabled", "false"))
		def.backpack_type = reader.optional_string(row, "backpack_type", "none")
		def.apply_on_pickup = reader.parse_bool(row.get("apply_on_pickup", "true"))
		def.effect_type = reader.optional_string(row, "effect_type", "")
		def.effect_target = reader.optional_string(row, "effect_target", "")
		def.effect_mode = reader.optional_string(row, "effect_mode", "")
		def.effect_value = reader.parse_int(row.get("effect_value", "0"))
		def.hotkey_action = reader.optional_string(row, "hotkey_action", "")
		def.hotkey_spawn_battle_item_id = reader.optional_string(row, "hotkey_spawn_battle_item_id", "")
		def.content_hash = "battle_item_%s_csv_v1" % battle_item_id

		var derived_dir := "%s/%s" % [DERIVED_ANIM_ROOT, battle_item_id]
		def.stand_anim_path = "%s/stand" % derived_dir
		def.icon_path = "%s/stand/frame_0000.png" % derived_dir

		if not def.trigger_source.is_empty():
			def.trigger_anim_path = "%s/trigger" % derived_dir
		else:
			def.trigger_anim_path = ""

		var output_path := OUTPUT_DIR + battle_item_id + ".tres"
		save_resource(def, output_path)
