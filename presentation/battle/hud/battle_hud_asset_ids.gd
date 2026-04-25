class_name BattleHudAssetIds
extends RefCounted

const TIMER_FRAME := "ui.battle.hud.timer.frame"
const COUNTDOWN_FRAME := "ui.battle.hud.countdown.frame"
const PLAYER_ROW := "ui.battle.hud.player_row"
const SCORE_PANEL := "ui.battle.hud.score_panel"
const TEAM_SCORE_RED := "ui.battle.hud.team_score.red"
const TEAM_SCORE_BLUE := "ui.battle.hud.team_score.blue"
const LOCAL_STATUS_FRAME := "ui.battle.hud.local_status.frame"
const HP_BAR_FRAME := "ui.battle.hud.hp_bar.frame"
const HP_BAR_FILL := "ui.battle.hud.hp_bar.fill"
const ITEM_SLOT_EMPTY := "ui.battle.item_slot.empty"
const ITEM_SLOT_ACTIVE := "ui.battle.item_slot.active"
const ITEM_SLOT_COOLDOWN := "ui.battle.item_slot.cooldown"
const TOAST_FRAME := "ui.battle.hud.toast.frame"
const NETWORK_GOOD := "ui.battle.hud.network.good"
const NETWORK_WARNING := "ui.battle.hud.network.warning"
const NETWORK_BAD := "ui.battle.hud.network.bad"


static func panel_asset_map() -> Dictionary:
	return {
		"countdown_panel": COUNTDOWN_FRAME,
		"player_status_panel": PLAYER_ROW,
		"network_status_panel": NETWORK_GOOD,
		"match_message_panel": TOAST_FRAME,
		"battle_meta_panel": TIMER_FRAME,
		"local_player_ability_panel": ITEM_SLOT_ACTIVE,
		"team_score_panel": SCORE_PANEL,
		"local_life_state_panel": LOCAL_STATUS_FRAME,
	}


static func required_asset_ids() -> Array[String]:
	return [
		TIMER_FRAME,
		COUNTDOWN_FRAME,
		PLAYER_ROW,
		SCORE_PANEL,
		TEAM_SCORE_RED,
		TEAM_SCORE_BLUE,
		LOCAL_STATUS_FRAME,
		HP_BAR_FRAME,
		HP_BAR_FILL,
		ITEM_SLOT_EMPTY,
		ITEM_SLOT_ACTIVE,
		ITEM_SLOT_COOLDOWN,
		TOAST_FRAME,
		NETWORK_GOOD,
		NETWORK_WARNING,
		NETWORK_BAD,
	]
