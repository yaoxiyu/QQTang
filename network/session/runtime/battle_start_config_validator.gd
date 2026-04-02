class_name BattleStartConfigValidator
extends RefCounted

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const RuleLoaderScript = preload("res://content/rules/rule_loader.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")

const ERROR_CODE_NULL_CONFIG := "MATCH_CONFIG_VALIDATE_NULL"
const ERROR_CODE_INVALID_CONFIG := "MATCH_CONFIG_VALIDATE_FAILED"

var expected_protocol_version: int = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
var expected_gameplay_rule_version: int = BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION
var dedicated_server_peer_id: int = 1


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
	var errors: Array = validation.get("errors", []).duplicate()
	var warnings: Array = validation.get("warnings", [])
	_validate_ds_contract(config, errors)
	_validate_content_contract(config, errors)
	var ok := bool(validation.get("ok", false))
	ok = errors.is_empty()
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


func _validate_ds_contract(config: BattleStartConfig, errors: Array) -> void:
	if config == null:
		return
	if String(config.topology) != "dedicated_server":
		return
	for player_entry in config.player_slots:
		var peer_id := int(player_entry.get("peer_id", -1))
		if peer_id == dedicated_server_peer_id:
			errors.append("dedicated_server topology must not include server peer in player_slots: %d" % dedicated_server_peer_id)
			break
	if String(config.session_mode) == "network_client":
		if config.local_peer_id <= 0:
			errors.append("network_client dedicated_server config requires local_peer_id")
		if config.controlled_peer_id <= 0:
			errors.append("network_client dedicated_server config requires controlled_peer_id")
	if String(config.session_mode) == "network_dedicated_server":
		if config.local_peer_id != 0:
			errors.append("network_dedicated_server config must not declare local_peer_id")
		if config.controlled_peer_id != 0:
			errors.append("network_dedicated_server config must not declare controlled_peer_id")


func _validate_content_contract(config: BattleStartConfig, errors: Array) -> void:
	if config == null:
		return
	if RuleLoaderScript.load_rule_config(config.rule_set_id).is_empty():
		errors.append("rule_set_id is invalid: %s" % config.rule_set_id)
	for loadout in config.character_loadouts:
		var character_id := String(loadout.get("character_id", ""))
		if not CharacterCatalogScript.has_character(character_id):
			errors.append("character_loadouts contains invalid character_id: %s" % character_id)
