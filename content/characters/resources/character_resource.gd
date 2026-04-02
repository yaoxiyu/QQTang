class_name CharacterResource
extends Resource

@export var character_id: String = ""
@export var display_name: String = ""
@export var base_bomb_count: int = 1
@export var base_firepower: int = 1
@export var base_move_speed: int = 1
@export var content_hash: String = ""


func to_loadout(peer_id: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"character_id": character_id,
		"display_name": display_name,
		"base_bomb_count": base_bomb_count,
		"base_firepower": base_firepower,
		"base_move_speed": base_move_speed,
		"content_hash": content_hash,
	}
