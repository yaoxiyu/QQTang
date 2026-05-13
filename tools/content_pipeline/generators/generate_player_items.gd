extends ContentCsvGeneratorBase
class_name GeneratePlayerItems

const INPUT_CSV_PATH := "res://content_source/csv/player_items/player_item.csv"
const OUTPUT_DIR := "res://content/items/data/player_item/"
const PlayerItemDefinitionScript = preload("res://content/items/defs/player_item_definition.gd")


func generate() -> void:
	var rows := read_csv_rows(INPUT_CSV_PATH)
	if rows.is_empty():
		push_error("player_item.csv has no data rows")
		return

	var reader := ContentCsvReaderScript.new()

	for row in rows:
		var player_item_id := reader.require_string(row, "player_item_id")
		if player_item_id.is_empty():
			continue

		var def := PlayerItemDefinitionScript.new()
		def.player_item_id = player_item_id
		def.display_name = reader.optional_string(row, "display_name", player_item_id)
		def.item_type = reader.optional_string(row, "item_type", "")
		def.icon_path = reader.optional_string(row, "icon_path", "")
		def.rarity = reader.optional_string(row, "rarity", "common")
		def.target_character_id = reader.optional_string(row, "target_character_id", "")
		def.skin_slot = reader.optional_string(row, "skin_slot", "")
		def.stackable = reader.parse_bool(row.get("stackable", "false"))
		def.max_stack = reader.parse_int(row.get("max_stack", "0"))
		def.content_hash = "player_item_%s_csv_v1" % player_item_id

		var output_path := OUTPUT_DIR + player_item_id + ".tres"
		save_resource(def, output_path)
