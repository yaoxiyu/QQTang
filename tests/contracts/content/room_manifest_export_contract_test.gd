extends "res://tests/gut/base/qqt_contract_test.gd"

const GenerateRoomManifestScript = preload("res://tools/content_pipeline/generators/generate_room_manifest.gd")
const MANIFEST_PATH := "res://build/generated/room_manifest/room_manifest.json"


func test_room_manifest_export_contract() -> void:
	GenerateRoomManifestScript.new().generate()

	assert_true(FileAccess.file_exists(MANIFEST_PATH), "room manifest file should exist")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert_true(file != null, "room manifest should be readable")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	assert_false(text.strip_edges().is_empty(), "room manifest content should not be empty")

	var parsed = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "room manifest should be a json object")
	if not parsed is Dictionary:
		return

	var manifest := parsed as Dictionary
	assert_true(manifest.has("schema_version"), "room manifest must include schema_version")
	assert_true(manifest.has("generated_at_unix_ms"), "room manifest must include generated_at_unix_ms")
	assert_true(manifest.has("maps"), "room manifest must include maps")
	assert_true(manifest.has("modes"), "room manifest must include modes")
	assert_true(manifest.has("rules"), "room manifest must include rules")
	assert_true(manifest.has("match_formats"), "room manifest must include match_formats")
	assert_true(manifest.has("assets"), "room manifest must include assets")
