class_name PassThroughAuthGateway
extends AuthGateway

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")


func login(request: LoginRequest) -> LoginResult:
	if request == null:
		return LoginResult.fail("LOGIN_REQUEST_INVALID", "Login request is missing")

	var nickname := request.nickname.strip_edges()
	if nickname.is_empty():
		return LoginResult.fail("LOGIN_NICKNAME_REQUIRED", "Nickname is required")

	var character_id := request.default_character_id.strip_edges()
	if character_id.is_empty() or not CharacterCatalogScript.has_character(character_id):
		return LoginResult.fail("LOGIN_CHARACTER_INVALID", "Default character selection is invalid")

	var bubble_style_id := request.default_bubble_style_id.strip_edges()
	if bubble_style_id.is_empty() or not BubbleCatalogScript.has_bubble(bubble_style_id):
		return LoginResult.fail("LOGIN_BUBBLE_INVALID", "Default bubble selection is invalid")

	var profile_id := request.profile_id.strip_edges()
	if profile_id.is_empty():
		profile_id = "local_guest"

	return LoginResult.success(
		"guest::%s" % profile_id,
		nickname,
		"pass_through",
		true,
		"Login succeeded"
	)
