class_name AudioTypes
extends RefCounted

enum Category {
	BGM_MAP,
	BGM_SCENE,
	BGM_RESULT,
	BGM_EVENT,
	SFX_BATTLE,
	SFX_UI,
	SFX_ITEM,
	SFX_VOICE,
	SFX_EVENT,
	SFX_NUMBERED_BATTLE,
	SFX_NUMBERED_SHORT,
	SFX_NUMBERED_EXTENDED,
	SFX_NUMBERED_STEREO,
	SFX_OR_STINGER_NUMBERED,
}

enum Bus {
	MASTER = 0,
	BGM = 1,
	SFX = 2,
	UI = 3,
	VOICE = 4,
	EVENT = 5,
}

const BUS_NAMES: Dictionary = {
	Bus.MASTER: "Master",
	Bus.BGM: "BGM",
	Bus.SFX: "SFX",
	Bus.UI: "UI",
	Bus.VOICE: "Voice",
	Bus.EVENT: "Event",
}

const CATEGORY_BUS_MAP: Dictionary = {
	Category.BGM_MAP: Bus.BGM,
	Category.BGM_SCENE: Bus.BGM,
	Category.BGM_RESULT: Bus.BGM,
	Category.BGM_EVENT: Bus.EVENT,
	Category.SFX_BATTLE: Bus.SFX,
	Category.SFX_UI: Bus.UI,
	Category.SFX_ITEM: Bus.SFX,
	Category.SFX_VOICE: Bus.VOICE,
	Category.SFX_EVENT: Bus.EVENT,
	Category.SFX_NUMBERED_BATTLE: Bus.SFX,
	Category.SFX_NUMBERED_SHORT: Bus.SFX,
	Category.SFX_NUMBERED_EXTENDED: Bus.SFX,
	Category.SFX_NUMBERED_STEREO: Bus.SFX,
	Category.SFX_OR_STINGER_NUMBERED: Bus.SFX,
}

static func to_category(category_str: String) -> int:
	match category_str:
		"BGM_MAP": return Category.BGM_MAP
		"BGM_SCENE": return Category.BGM_SCENE
		"BGM_RESULT": return Category.BGM_RESULT
		"BGM_EVENT": return Category.BGM_EVENT
		"SFX_BATTLE": return Category.SFX_BATTLE
		"SFX_UI": return Category.SFX_UI
		"SFX_ITEM": return Category.SFX_ITEM
		"SFX_VOICE": return Category.SFX_VOICE
		"SFX_EVENT": return Category.SFX_EVENT
		"SFX_NUMBERED_BATTLE": return Category.SFX_NUMBERED_BATTLE
		"SFX_NUMBERED_SHORT": return Category.SFX_NUMBERED_SHORT
		"SFX_NUMBERED_EXTENDED": return Category.SFX_NUMBERED_EXTENDED
		"SFX_NUMBERED_STEREO": return Category.SFX_NUMBERED_STEREO
		"SFX_OR_STINGER_NUMBERED": return Category.SFX_OR_STINGER_NUMBERED
		_: return -1

static func to_bus(bus_str: String) -> int:
	match bus_str:
		"Master": return Bus.MASTER
		"BGM": return Bus.BGM
		"SFX": return Bus.SFX
		"UI": return Bus.UI
		"Voice": return Bus.VOICE
		"Event": return Bus.EVENT
		_: return -1

static func is_bgm_category(category: int) -> bool:
	return category == Category.BGM_MAP or category == Category.BGM_SCENE or category == Category.BGM_RESULT or category == Category.BGM_EVENT
