extends RefCounted

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const AuthSessionRepositoryScript = preload("res://app/front/auth/auth_session_repository.gd")
const LocalAuthSessionRepositoryScript = preload("res://app/front/auth/local_auth_session_repository.gd")
const HttpAuthGatewayScript = preload("res://app/front/auth/http_auth_gateway.gd")
const HttpRoomTicketGatewayScript = preload("res://app/front/auth/http_room_ticket_gateway.gd")
const LoginUseCaseScript = preload("res://app/front/auth/login_use_case.gd")
const PassThroughAuthGatewayScript = preload("res://app/front/auth/pass_through_auth_gateway.gd")
const LobbyUseCaseScript = preload("res://app/front/lobby/lobby_use_case.gd")
const LobbyDirectoryUseCaseScript = preload("res://app/front/lobby/lobby_directory_use_case.gd")
const PracticeRoomFactoryScript = preload("res://app/front/lobby/practice_room_factory.gd")
const CareerUseCaseScript = preload("res://app/front/career/career_use_case.gd")
const HttpCareerGatewayScript = preload("res://app/front/career/http_career_gateway.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const FrontSettingsRepositoryScript = preload("res://app/front/profile/front_settings_repository.gd")
const HttpProfileGatewayScript = preload("res://app/front/profile/http_profile_gateway.gd")
const LocalFrontSettingsRepositoryScript = preload("res://app/front/profile/local_front_settings_repository.gd")
const LocalProfileRepositoryScript = preload("res://app/front/profile/local_profile_repository.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")
const ProfileRepositoryScript = preload("res://app/front/profile/profile_repository.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const RoomUseCaseScript = preload("res://app/front/room/room_use_case.gd")
const SettlementSyncUseCaseScript = preload("res://app/front/settlement/settlement_sync_use_case.gd")
const HttpSettlementGatewayScript = preload("res://app/front/settlement/http_settlement_gateway.gd")
const LoadingUseCaseScript = preload("res://app/front/loading/loading_use_case.gd")
const AppRuntimeConfigScript = preload("res://app/flow/app_runtime_config.gd")
const FrontRuntimeContextScript = preload("res://app/flow/front_runtime_context.gd")
const BattleRuntimeContextScript = preload("res://app/flow/battle_runtime_context.gd")


static func ensure_runtime_config(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.runtime_config == null:
		runtime.runtime_config = AppRuntimeConfigScript.new()


static func ensure_runtime_contexts(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.front_context == null:
		runtime.front_context = FrontRuntimeContextScript.new()
	if runtime.battle_context == null:
		runtime.battle_context = BattleRuntimeContextScript.new()
	if runtime.has_method("_sync_front_context_from_fields"):
		runtime._sync_front_context_from_fields()
	if runtime.has_method("_sync_battle_context_from_fields"):
		runtime._sync_battle_context_from_fields()


static func ensure_front_repositories(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.auth_session_repository == null:
		runtime.auth_session_repository = LocalAuthSessionRepositoryScript.new()
	elif not (runtime.auth_session_repository is AuthSessionRepositoryScript):
		runtime.auth_session_repository = LocalAuthSessionRepositoryScript.new()

	if runtime.profile_repository == null:
		runtime.profile_repository = LocalProfileRepositoryScript.new()
	elif not (runtime.profile_repository is ProfileRepositoryScript):
		runtime.profile_repository = LocalProfileRepositoryScript.new()

	if runtime.front_settings_repository == null:
		runtime.front_settings_repository = LocalFrontSettingsRepositoryScript.new()
	elif not (runtime.front_settings_repository is FrontSettingsRepositoryScript):
		runtime.front_settings_repository = LocalFrontSettingsRepositoryScript.new()


static func ensure_front_local_state(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.auth_session_state == null:
		runtime.auth_session_state = AuthSessionStateScript.new()
	if runtime.player_profile_state == null:
		runtime.player_profile_state = PlayerProfileStateScript.new()
	if runtime.front_settings_state == null:
		runtime.front_settings_state = FrontSettingsStateScript.new()

	if runtime.auth_session_repository != null and runtime.auth_session_repository.has_method("load_session"):
		runtime.auth_session_state = runtime.auth_session_repository.load_session()
		if runtime.auth_session_state == null:
			runtime.auth_session_state = AuthSessionStateScript.new()
	if runtime.profile_repository != null and runtime.profile_repository.has_method("load_profile"):
		runtime.player_profile_state = runtime.profile_repository.load_profile()
		if runtime.player_profile_state == null:
			runtime.player_profile_state = PlayerProfileStateScript.new()
	if runtime.front_settings_repository != null and runtime.front_settings_repository.has_method("load_settings"):
		runtime.front_settings_state = runtime.front_settings_repository.load_settings()
		if runtime.front_settings_state == null:
			runtime.front_settings_state = FrontSettingsStateScript.new()
	if runtime.has_method("_sync_front_context_from_fields"):
		runtime._sync_front_context_from_fields()


static func ensure_front_services(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.auth_gateway == null:
		runtime.auth_gateway = HttpAuthGatewayScript.new()
	if runtime.runtime_config != null and bool(runtime.runtime_config.enable_pass_through_auth_fallback):
		runtime.auth_gateway = PassThroughAuthGatewayScript.new()
	if runtime.profile_gateway == null:
		runtime.profile_gateway = HttpProfileGatewayScript.new()
	if runtime.room_ticket_gateway == null:
		runtime.room_ticket_gateway = HttpRoomTicketGatewayScript.new()
	if runtime.career_gateway == null:
		runtime.career_gateway = HttpCareerGatewayScript.new()
	if runtime.settlement_gateway == null:
		runtime.settlement_gateway = HttpSettlementGatewayScript.new()
	if runtime.practice_room_factory == null:
		runtime.practice_room_factory = PracticeRoomFactoryScript.new()


static func ensure_front_use_cases(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.login_use_case == null:
		runtime.login_use_case = LoginUseCaseScript.new()
	if runtime.login_use_case != null and runtime.login_use_case.has_method("configure"):
		runtime.login_use_case.configure(
			runtime.auth_gateway,
			runtime.auth_session_state,
			runtime.auth_session_repository,
			runtime.profile_gateway,
			runtime.profile_repository,
			runtime.front_settings_repository,
			runtime.player_profile_state,
			runtime.front_settings_state
		)

	if runtime.lobby_use_case == null:
		runtime.lobby_use_case = LobbyUseCaseScript.new()
	if runtime.lobby_use_case != null and runtime.lobby_use_case.has_method("configure"):
		runtime.lobby_use_case.configure(
			runtime,
			runtime.auth_session_state,
			runtime.player_profile_state,
			runtime.front_settings_state,
			runtime.practice_room_factory,
			runtime.auth_session_repository,
			runtime.logout_use_case,
			runtime.profile_gateway,
			runtime.room_ticket_gateway
		)

	if runtime.lobby_directory_use_case == null:
		runtime.lobby_directory_use_case = LobbyDirectoryUseCaseScript.new()
	if runtime.lobby_directory_use_case != null and runtime.lobby_directory_use_case.has_method("configure"):
		runtime.lobby_directory_use_case.configure(
			runtime.client_room_runtime,
			runtime.front_settings_state
		)

	if runtime.career_use_case == null:
		runtime.career_use_case = CareerUseCaseScript.new()
	if runtime.career_use_case != null and runtime.career_use_case.has_method("configure"):
		runtime.career_use_case.configure(
			runtime.auth_session_state,
			runtime.front_settings_state,
			runtime.career_gateway
		)

	if runtime.room_use_case == null:
		runtime.room_use_case = RoomUseCaseScript.new()
	if runtime.room_use_case != null and runtime.room_use_case.has_method("configure"):
		runtime.room_use_case.configure(runtime)

	if runtime.current_room_entry_context == null:
		runtime.current_room_entry_context = RoomEntryContextScript.new()
	if runtime.has_method("_sync_front_context_from_fields"):
		runtime._sync_front_context_from_fields()

	if runtime.loading_use_case == null:
		runtime.loading_use_case = LoadingUseCaseScript.new()
	if runtime.loading_use_case != null and runtime.loading_use_case.has_method("configure"):
		var gateway = null
		if runtime.room_use_case != null:
			gateway = runtime.room_use_case.get("room_client_gateway")
		runtime.loading_use_case.configure(runtime, gateway)

	if runtime.settlement_sync_use_case == null:
		runtime.settlement_sync_use_case = SettlementSyncUseCaseScript.new()
	if runtime.settlement_sync_use_case != null and runtime.settlement_sync_use_case.has_method("configure"):
		runtime.settlement_sync_use_case.configure(
			runtime.auth_session_state,
			runtime.front_settings_state,
			runtime.settlement_gateway
		)

	if runtime.auth_session_restore_use_case == null:
		var restore_script = _try_load_script("res://app/front/auth/auth_session_restore_use_case.gd")
		if restore_script != null:
			runtime.auth_session_restore_use_case = restore_script.new()
	if runtime.auth_session_restore_use_case != null and runtime.auth_session_restore_use_case.has_method("configure"):
		runtime.auth_session_restore_use_case.configure(runtime)

	if runtime.register_use_case == null:
		var register_script = _try_load_script("res://app/front/auth/register_use_case.gd")
		if register_script != null:
			runtime.register_use_case = register_script.new()
	if runtime.register_use_case != null and runtime.register_use_case.has_method("configure"):
		runtime.register_use_case.configure(runtime)

	if runtime.refresh_session_use_case == null:
		var refresh_script = _try_load_script("res://app/front/auth/refresh_session_use_case.gd")
		if refresh_script != null:
			runtime.refresh_session_use_case = refresh_script.new()
	if runtime.refresh_session_use_case != null and runtime.refresh_session_use_case.has_method("configure"):
		runtime.refresh_session_use_case.configure(runtime)

	if runtime.logout_use_case == null:
		var logout_script = _try_load_script("res://app/front/auth/logout_use_case.gd")
		if logout_script != null:
			runtime.logout_use_case = logout_script.new()
	if runtime.logout_use_case != null and runtime.logout_use_case.has_method("configure"):
		runtime.logout_use_case.configure(runtime)


static func _try_load_script(path: String):
	if not ResourceLoader.exists(path):
		return null
	return load(path)
