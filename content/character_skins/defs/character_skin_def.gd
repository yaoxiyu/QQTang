extends Resource
class_name CharacterSkinDef

@export var skin_id: String = ""
@export var display_name: String = ""
@export var overlay_scene: PackedScene
@export var applicable_slots: PackedStringArray = ["body_overlay"]
@export var ui_icon: Texture2D
@export var rarity: String = "normal"
@export var tags: PackedStringArray = []
@export var slot_offsets: Dictionary = {}
