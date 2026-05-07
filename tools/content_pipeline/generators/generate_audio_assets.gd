extends ContentCsvGeneratorBase
class_name GenerateAudioAssets

const INPUT_CSV_PATH := "res://content_source/csv/audio/audio_assets.csv"
const OUTPUT_DIR_BGM := "res://content/audio/data/bgm/"
const OUTPUT_DIR_SFX := "res://content/audio/data/sfx/"
const AudioAssetDefScript = preload("res://content/audio/defs/audio_asset_def.gd")

func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("audio_assets.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var def := AudioAssetDefScript.new()
		def.audio_id = get_cell(row, header_index, "audio_id")
		def.category = get_cell(row, header_index, "category")
		def.bus = get_cell(row, header_index, "bus")
		def.audio_resource_path = get_cell(row, header_index, "resource_path")
		def.playback_policy = get_cell(row, header_index, "playback_policy")
		def.loop = get_cell(row, header_index, "loop") == "true"
		def.volume_db = float(get_cell(row, header_index, "volume_db"))
		def.preload_enabled = get_cell(row, header_index, "preload") == "true"
		def.alias_of = get_cell(row, header_index, "alias_of")

		var category := def.category
		var output_dir := OUTPUT_DIR_BGM if category.begins_with("BGM_") else OUTPUT_DIR_SFX
		var output_path := output_dir + def.audio_id + ".tres"
		save_resource(def, output_path)
