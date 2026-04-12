class_name RoomTicketGateway
extends RefCounted

const RoomTicketResultScript = preload("res://app/front/auth/room_ticket_result.gd")

func configure_base_url(base_url: String) -> void:
	pass


func issue_room_ticket(access_token: String, request):
	return RoomTicketResultScript.fail("NOT_IMPLEMENTED", "RoomTicketGateway.issue_room_ticket not implemented")
