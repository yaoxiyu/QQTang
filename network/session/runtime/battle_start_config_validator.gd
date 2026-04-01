class_name BattleStartConfigValidator
extends RefCounted

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")

const ERROR_CODE_NULL_CONFIG := "MATCH_CONFIG_VALIDATE_NULL"
const ERROR_CODE_INVALID_CONFIG := "MATCH_CONFIG_VALIDATE_FAILED"

var expected_protocol_version: int = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
var expected_gameplay_rule_version: int = BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION


func validate_start_config(config: BattleStartConfig) -> Dictionary:
	if config == null:
		return {
			"ok": false,
			"error_code": ERROR_CODE_NULL_CONFIG,
			"error_message": "BattleStartConfig is null",
			"details": {
				"errors": ["BattleStartConfig is null"],
				"warnings": [],
			},
			"errors": ["BattleStartConfig is null"],
			"warnings": [],
		}

	var validation := config.validate({
		"expected_protocol_version": expected_protocol_version,
		"expected_gameplay_rule_version": expected_gameplay_rule_version,
		"map_metadata": _load_map_metadata(config.map_id),
	})
	var errors: Array = validation.get("errors", [])
	var warnings: Array = validation.get("warnings", [])
	var ok := bool(validation.get("ok", false))
	return {
		"ok": ok,
		"error_code": "" if ok else ERROR_CODE_INVALID_CONFIG,
		"error_message": "" if ok else _build_error_message(errors),
		"details": {
			"errors": errors,
			"warnings": warnings,
			"match_id": config.match_id if config != null else "",
			"room_id": config.room_id if config != null else "",
			"map_id": config.map_id if config != null else "",
			"rule_set_id": config.rule_set_id if config != null else "",
		},
		"errors": errors,
		"warnings": warnings,
	}


func _load_map_metadata(map_id: String) -> Dictionary:
	return MapLoaderScript.load_map_metadata(map_id)


func _build_error_message(errors: Array) -> String:
	if errors.is_empty():
		return "BattleStartConfig validation failed"
	return String(errors[0])
