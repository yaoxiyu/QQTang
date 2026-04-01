extends Node

const BattleStartConfigBuilderScript = preload("res://network/session/runtime/battle_start_config_builder.gd")
const BattleStartConfigValidatorScript = preload("res://network/session/runtime/battle_start_config_validator.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")

signal battle_start_config_built(config: BattleStartConfig)

var match_id_prefix: String = "match"
var next_match_sequence: int = 1
var forced_seed: int = -1
var _builder: BattleStartConfigBuilder = BattleStartConfigBuilderScript.new()
var _validator: BattleStartConfigValidator = BattleStartConfigValidatorScript.new()


func can_build_from_room(snapshot: RoomSnapshot) -> bool:
	_sync_builder_settings()
	return _builder.can_build_from_room(snapshot)


func build_start_config(snapshot: RoomSnapshot) -> BattleStartConfig:
	var result := prepare_start_config(snapshot)
	return result.get("config", BattleStartConfig.new())


func prepare_start_config(snapshot: RoomSnapshot) -> Dictionary:
	_sync_builder_settings()
	_sync_validator_settings()

	if snapshot == null:
		return {
			"ok": false,
			"config": null,
			"validation": {
				"ok": false,
				"error_code": NetworkErrorCodesScript.MATCH_CONFIG_BUILD_FAILED,
				"error_message": "Room snapshot is required",
				"details": {},
				"errors": ["room snapshot is required"],
				"warnings": [],
			},
		}

	if not _builder.can_build_from_room(snapshot):
		return {
			"ok": false,
			"config": null,
			"validation": {
				"ok": false,
				"error_code": NetworkErrorCodesScript.MATCH_CONFIG_BUILD_FAILED,
				"error_message": "Room state is not ready to build battle start config",
				"details": {
					"snapshot": snapshot.to_dict(),
				},
				"errors": ["room state is not ready to build battle start config"],
				"warnings": [],
			},
		}

	var room_runtime_context := _resolve_room_runtime_context()
	var config := _builder.build_start_config(snapshot, room_runtime_context)
	var validation := _validator.validate_start_config(config)
	if not bool(validation.get("ok", false)):
		push_error("Invalid BattleStartConfig: %s" % str(validation.get("errors", [])))
		return {
			"ok": false,
			"config": config,
			"validation": validation,
		}

	next_match_sequence = _builder.next_match_sequence
	battle_start_config_built.emit(config)
	return {
		"ok": true,
		"config": config,
		"validation": validation,
	}


func assign_spawn_slots(snapshot: RoomSnapshot) -> Array[Dictionary]:
	_sync_builder_settings()
	return _builder.assign_spawn_slots(snapshot)


func generate_seed() -> int:
	_sync_builder_settings()
	return _builder.generate_seed()


func validate_start_config(config: BattleStartConfig) -> Dictionary:
	_sync_validator_settings()
	return _validator.validate_start_config(config)


func debug_dump_start_config(snapshot: RoomSnapshot) -> Dictionary:
	_sync_builder_settings()
	var room_runtime_context := _resolve_room_runtime_context()
	return _builder.debug_dump_start_config(snapshot, room_runtime_context)


func _resolve_room_runtime_context() -> RoomRuntimeContext:
	var room_runtime_context: RoomRuntimeContext = null
	if get_parent() != null and get_parent().has_node("RoomSessionController"):
		var room_controller := get_parent().get_node("RoomSessionController")
		if room_controller != null:
			room_runtime_context = room_controller.room_runtime_context
	return room_runtime_context


func _sync_builder_settings() -> void:
	if _builder == null:
		_builder = BattleStartConfigBuilderScript.new()
	_builder.match_id_prefix = match_id_prefix
	_builder.next_match_sequence = next_match_sequence
	_builder.forced_seed = forced_seed


func _sync_validator_settings() -> void:
	if _validator == null:
		_validator = BattleStartConfigValidatorScript.new()
