class_name BattleAudioEventConfig
extends RefCounted

const SFX_BUBBLE_PLACE := "x09_01"
const SFX_ITEM_PICK := "x08_01"
const SFX_ITEM_DROP_AIRPLANE := "x05_01"
const SFX_READY_GO := "ready_go"
const SFX_BUBBLE_EXPLODE := "x10_01"
const SFX_JELLY_RESCUED_MALE := "x40_01"
const SFX_JELLY_RESCUED_FEMALE := "x39_01"
const SFX_JELLY_EXECUTED := "x12_01"
const BGM_RESULT_WIN := "player_win"
const BGM_RESULT_LOSS := "player_loss"

const EXPLOSION_VOLUME_STEP_DB := 1.5
const EXPLOSION_VOLUME_MAX_DB := 6.0


static func explosion_volume_boost_db(explosion_count: int) -> float:
	if explosion_count <= 1:
		return 0.0
	return min(EXPLOSION_VOLUME_MAX_DB, float(explosion_count - 1) * EXPLOSION_VOLUME_STEP_DB)
