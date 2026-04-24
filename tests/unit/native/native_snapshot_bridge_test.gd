extends QQTUnitTest


func test_pack_and_unpack_preserve_snapshot_payload() -> void:
	var bridge := NativeSnapshotBridge.new()
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = 12
	snapshot.rng_state = 9988
	snapshot.players = [{"entity_id": 1, "cell_x": 3, "cell_y": 4, "alive": true}]
	snapshot.bubbles = [{"entity_id": 5, "cell_x": 7, "cell_y": 8, "ignore_player_ids": [1]}]
	snapshot.items = [{"entity_id": 9, "item_type": 2, "cell_x": 6, "cell_y": 1}]
	snapshot.walls = [{"cell_x": 0, "cell_y": 0, "tile_type": 1, "tile_flags": 4, "theme_variant": 0}]
	snapshot.match_state = {"phase": 1, "winner_team_id": -1, "winner_player_id": -1, "ended_reason": 0, "remaining_ticks": 90}
	snapshot.mode_state = {"mode_runtime_type": "default", "mode_timer_ticks": 90, "payload_owner_id": -1}
	snapshot.checksum = 123456

	var packed := bridge.pack_snapshot(snapshot)
	var unpacked := bridge.unpack_snapshot(packed)

	assert_true(not packed.is_empty(), "snapshot bridge should encode non-empty payload")
	assert_true(unpacked != null, "snapshot bridge should decode snapshot payload")
	assert_eq(unpacked.tick_id, snapshot.tick_id, "tick_id should roundtrip")
	assert_eq(unpacked.rng_state, snapshot.rng_state, "rng_state should roundtrip")
	assert_eq(unpacked.players, snapshot.players, "players should roundtrip")
	assert_eq(unpacked.bubbles, snapshot.bubbles, "bubbles should roundtrip")
	assert_eq(unpacked.items, snapshot.items, "items should roundtrip")
	assert_eq(unpacked.walls, snapshot.walls, "walls should roundtrip")
	assert_eq(unpacked.match_state, snapshot.match_state, "match_state should roundtrip")
	assert_eq(unpacked.mode_state, snapshot.mode_state, "mode_state should roundtrip")
	assert_eq(unpacked.checksum, snapshot.checksum, "checksum should roundtrip")


func test_snapshot_payload_contains_battle_packed_state_when_native_codec_available() -> void:
	if not ClassDB.can_instantiate("QQTNativePackedStateCodec"):
		pending("native packed state codec is not available in this runtime")
		return
	var bridge := NativePackedStateCodecBridge.new()
	var codec = ClassDB.instantiate("QQTNativePackedStateCodec")
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = 21
	snapshot.players = [{"entity_id": 1, "cell_x": 3, "cell_y": 4, "alive": true}]
	snapshot.bubbles = [{"entity_id": 5, "cell_x": 7, "cell_y": 8}]
	snapshot.items = [{"entity_id": 9, "item_type": 2, "cell_x": 6, "cell_y": 1}]
	snapshot.walls = [{"cell_x": 0, "cell_y": 0, "tile_type": 1, "tile_flags": 4}]

	var payload: Dictionary = codec.unpack_snapshot_payload(bridge.encode_snapshot_payload(snapshot))
	var packed_state: Dictionary = payload.get("battle_packed_state", {})

	assert_false(packed_state.is_empty(), "native payload should carry battle packed state")
	assert_eq(int(packed_state.get("schema_version", 0)), NativeBattlePackedSchema.SCHEMA_VERSION, "packed state schema version should be present")
	assert_eq(NativeBattlePackedStateReader.get_tick_id(packed_state), snapshot.tick_id, "packed state tick should match snapshot tick")
	assert_eq(NativeBattlePackedStateReader.get_player_count(packed_state), 1, "packed state should include players")


func test_unpack_rejects_snapshot_payload_with_wrong_version() -> void:
	var bridge := NativePackedStateCodecBridge.new()
	var raw_payload := {
		"version": 999,
		"tick_id": 3,
		"rng_state": 5,
		"players": [],
		"bubbles": [],
		"items": [],
		"walls": [],
		"match_state": {},
		"mode_state": {},
		"checksum": 7,
	}

	var unpacked := bridge.decode_snapshot_payload(var_to_bytes(raw_payload))

	assert_true(unpacked == null, "snapshot payload with wrong version should be rejected")
