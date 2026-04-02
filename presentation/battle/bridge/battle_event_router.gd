class_name BattleEventRouter
extends Node

signal explosion_event_routed(event: SimEvent)
signal cell_destroyed_event_routed(event: SimEvent)
signal player_killed_event_routed(event: SimEvent)
signal item_spawned_event_routed(event: SimEvent)
signal item_picked_event_routed(event: SimEvent)
signal match_ended_event_routed(event: SimEvent)


func route_events(events: Array) -> void:
	for event in events:
		if event == null:
			continue

		match int(event.event_type):
			SimEvent.EventType.BUBBLE_EXPLODED:
				explosion_event_routed.emit(event)
			SimEvent.EventType.CELL_DESTROYED:
				cell_destroyed_event_routed.emit(event)
			SimEvent.EventType.PLAYER_KILLED:
				player_killed_event_routed.emit(event)
			SimEvent.EventType.ITEM_SPAWNED:
				item_spawned_event_routed.emit(event)
			SimEvent.EventType.ITEM_PICKED:
				item_picked_event_routed.emit(event)
			SimEvent.EventType.MATCH_ENDED:
				match_ended_event_routed.emit(event)
			_:
				pass
