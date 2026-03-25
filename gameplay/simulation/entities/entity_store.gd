extends RefCounted

class_name EntityStore

var entities: Dictionary = {}
var next_id: int = 1


func create_entity(data: Variant) -> int:
	var id: int = next_id
	next_id += 1
	entities[id] = data
	return id


func get_entity(id: int) -> Variant:
	return entities.get(id)

func remove_entity(id: int) -> void:
	entities.erase(id)


func remove(id: int) -> void:
	remove_entity(id)


func has_entity(id: int) -> bool:
	return entities.has(id)


func all_entities() -> Dictionary:
	return entities.duplicate(true)


func clear() -> void:
	entities.clear()
	next_id = 1
