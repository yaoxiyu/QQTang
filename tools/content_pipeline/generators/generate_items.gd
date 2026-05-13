extends ContentCsvGeneratorBase
class_name GenerateItems

const INPUT_CSV_PATH := "res://content_source/csv/items/items.csv"
const OUTPUT_DIR := "res://content/items/data/item/"
const ItemDefinitionScript = preload("res://content/items/defs/item_definition.gd")

const DERIVED_ANIM_ROOT := "res://external/assets/derived/assets/animation/items"


func generate() -> void:
	var rows := read_csv_rows(INPUT_CSV_PATH)
	if rows.is_empty():
		push_error("items.csv has no data rows")
		return

	var reader := ContentCsvReaderScript.new()

	for row in rows:
		var item_id := reader.require_string(row, "item_id")
		if item_id.is_empty():
			continue

		var def := ItemDefinitionScript.new()
		def.item_id = item_id
		def.display_name = reader.optional_string(row, "display_name", "Item %s" % item_id)
		def.description = reader.optional_string(row, "description", "")
		def.item_type = reader.parse_int(row.get("item_type", "0"))
		def.pickup_effect_type = reader.optional_string(row, "pickup_effect_type", "unknown")
		def.rarity = reader.optional_string(row, "rarity", "common")
		def.enabled = reader.parse_bool(row.get("enabled", "false"))
		def.content_hash = "item_%s_csv_v1" % item_id

		var derived_dir := "%s/%s" % [DERIVED_ANIM_ROOT, item_id]
		def.stand_anim_path = "%s/stand" % derived_dir
		def.icon_path = "%s/stand/frame_0000.png" % derived_dir

		var trigger_source := reader.optional_string(row, "trigger_source", "")
		if not trigger_source.is_empty():
			def.trigger_anim_path = "%s/trigger" % derived_dir
		else:
			def.trigger_anim_path = ""

		var output_path := OUTPUT_DIR + item_id + ".tres"
		save_resource(def, output_path)
