@tool
extends EditorScript
class_name ContentPipelineRunner

const GenerateCharactersScript = preload("res://tools/content_pipeline/generators/generate_characters.gd")
const GenerateCharacterStatsScript = preload("res://tools/content_pipeline/generators/generate_character_stats.gd")
const GenerateCharacterPresentationsScript = preload("res://tools/content_pipeline/generators/generate_character_presentations.gd")
const GenerateBubbleStylesScript = preload("res://tools/content_pipeline/generators/generate_bubble_styles.gd")
const GenerateBubbleGameplaysScript = preload("res://tools/content_pipeline/generators/generate_bubble_gameplays.gd")
const GenerateModesScript = preload("res://tools/content_pipeline/generators/generate_modes.gd")
const GenerateCharacterSkinsScript = preload("res://tools/content_pipeline/generators/generate_character_skins.gd")
const GenerateBubbleSkinsScript = preload("res://tools/content_pipeline/generators/generate_bubble_skins.gd")
const GenerateMapThemesScript = preload("res://tools/content_pipeline/generators/generate_map_themes.gd")
const GenerateRulesetsScript = preload("res://tools/content_pipeline/generators/generate_rulesets.gd")


func _run() -> void:
	run_all()


func run_all() -> void:
	GenerateCharactersScript.new().generate()
	GenerateCharacterStatsScript.new().generate()
	GenerateCharacterPresentationsScript.new().generate()
	GenerateBubbleStylesScript.new().generate()
	GenerateBubbleGameplaysScript.new().generate()
	GenerateModesScript.new().generate()
	GenerateCharacterSkinsScript.new().generate()
	GenerateBubbleSkinsScript.new().generate()
	GenerateMapThemesScript.new().generate()
	GenerateRulesetsScript.new().generate()
	print("ContentPipelineRunner: generation finished")
