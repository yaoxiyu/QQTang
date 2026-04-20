param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [string]$PowerShellExe = 'powershell',
    [switch]$SkipDb,
    [switch]$SkipMigration,
    [switch]$LogSQL,
    [string]$GodotExecutable = 'Godot_console.exe',
    [int]$DSMPortRangeStart = 19010,
    [int]$DSMPortRangeEnd = 19050,
    [string]$LogDir = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

$root = Resolve-QQTProjectRoot $ProjectPath
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $root

if (-not $SkipDb) {
    & (Join-Path $PSScriptRoot 'db-up.ps1') -Profile $Profile -ProjectPath $root
}
if (-not $SkipMigration) {
    & (Join-Path $PSScriptRoot 'db-migrate.ps1') -Profile $Profile -ProjectPath $root -SkipDbUp
}
& (Join-Path $root 'scripts\content\generate_room_manifest.ps1') -ProjectPath $root -GodotExecutable $GodotExecutable

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $LogDir = Join-Path $root (Join-Path 'logs' "services_${Profile}_$timestamp")
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$accountRoot = Join-Path $root 'services\account_service'
$gameRoot = Join-Path $root 'services\game_service'
$dsmRoot = Join-Path $root 'services\ds_manager_service'
$roomRoot = Join-Path $root 'services\room_service'

$internalSecret = 'dev_internal_shared_secret'
$tokenSecret = 'replace_me_access_secret'
$roomTicketSecret = 'dev_room_ticket_secret'
$battleTicketSecret = 'dev_battle_ticket_secret'

$accountEnv = @{
    'ACCOUNT_HTTP_LISTEN_ADDR' = $cfg.Account.ListenAddr
    'ACCOUNT_POSTGRES_DSN' = "postgres://$($cfg.Account.User):$($cfg.Account.Password)@127.0.0.1:$($cfg.Account.Port)/$($cfg.Account.Database)?sslmode=disable"
    'ACCOUNT_ACCESS_TOKEN_TTL_SECONDS' = '900'
    'ACCOUNT_REFRESH_TOKEN_TTL_SECONDS' = '1209600'
    'ACCOUNT_ROOM_TICKET_TTL_SECONDS' = '60'
    'ACCOUNT_BATTLE_TICKET_TTL_SECONDS' = '60'
    'ACCOUNT_TOKEN_SIGN_SECRET' = $tokenSecret
    'ACCOUNT_ROOM_TICKET_SIGN_SECRET' = $roomTicketSecret
    'ACCOUNT_BATTLE_TICKET_SIGN_SECRET' = $battleTicketSecret
    'ACCOUNT_GAME_SERVICE_BASE_URL' = "http://$($cfg.Game.ListenAddr)"
    'ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID' = 'primary'
    'ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET' = $internalSecret
    'ACCOUNT_GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS' = '60'
    'ACCOUNT_ALLOW_MULTI_DEVICE' = 'false'
    'ACCOUNT_LOG_SQL' = $(if ($LogSQL) { 'true' } else { 'false' })
}

$gameEnv = @{
    'GAME_HTTP_ADDR' = $cfg.Game.ListenAddr
    'GAME_POSTGRES_DSN' = "postgres://$($cfg.Game.User):$($cfg.Game.Password)@127.0.0.1:$($cfg.Game.Port)/$($cfg.Game.Database)?sslmode=disable"
    'GAME_JWT_SHARED_SECRET' = $tokenSecret
    'GAME_INTERNAL_AUTH_KEY_ID' = 'primary'
    'GAME_INTERNAL_AUTH_SHARED_SECRET' = $internalSecret
    'GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS' = '60'
    'GAME_DEFAULT_DS_HOST' = $cfg.Room.Host
    'GAME_DEFAULT_DS_PORT' = [string]$cfg.Room.Port
    'GAME_DS_MANAGER_URL' = "http://$($cfg.DSM.ListenAddr)"
    'GAME_QUEUE_HEARTBEAT_TTL_SECONDS' = '30'
    'GAME_CAPTAIN_DEADLINE_SECONDS' = '15'
    'GAME_COMMIT_DEADLINE_SECONDS' = '45'
    'GAME_LOG_SQL' = $(if ($LogSQL) { 'true' } else { 'false' })
}

$dsmEnv = @{
    'DSM_HTTP_ADDR' = $cfg.DSM.ListenAddr
    'DSM_GODOT_EXECUTABLE' = $GodotExecutable
    'DSM_PROJECT_ROOT' = $root
    'DSM_BATTLE_SCENE_PATH' = 'res://scenes/network/dedicated_server_scene.tscn'
    'DSM_BATTLE_TICKET_SECRET' = $battleTicketSecret
    'DSM_DS_HOST' = $cfg.Room.Host
    'DSM_PORT_RANGE_START' = [string]$DSMPortRangeStart
    'DSM_PORT_RANGE_END' = [string]$DSMPortRangeEnd
    'DSM_READY_TIMEOUT_SEC' = '15'
    'DSM_IDLE_REAP_TIMEOUT_SEC' = '300'
    'DSM_INTERNAL_AUTH_KEY_ID' = 'primary'
    'DSM_INTERNAL_AUTH_SHARED_SECRET' = $internalSecret
    'DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS' = '60'
    'GAME_SERVICE_HOST' = ($cfg.Game.ListenAddr -split ':')[0]
    'GAME_SERVICE_PORT' = ($cfg.Game.ListenAddr -split ':')[1]
    'GAME_INTERNAL_AUTH_KEY_ID' = 'primary'
    'GAME_INTERNAL_AUTH_SHARED_SECRET' = $internalSecret
}

$roomEnv = @{
    'ROOM_WS_ADDR' = "$($cfg.Room.Host):$($cfg.Room.Port)"
    'ROOM_HTTP_ADDR' = '127.0.0.1:19100'
    'ROOM_DEFAULT_PORT' = [string]$cfg.Room.Port
    'ROOM_TICKET_SECRET' = $roomTicketSecret
    'ROOM_MANIFEST_PATH' = '../../build/generated/room_manifest/room_manifest.json'
    'ROOM_GAME_SERVICE_GRPC_ADDR' = '127.0.0.1:19081'
    'ROOM_LOG_LEVEL' = 'info'
    'ROOM_ENV' = 'development'
    'ROOM_INSTANCE_ID' = "room-instance-$Profile"
    'ROOM_SHARD_ID' = "room-shard-$Profile"
}

$processes = @()
$processes += Start-QQTServiceWindow -PowerShellExe $PowerShellExe -Title "QQTang account_service : $($cfg.Account.ListenAddr)" -WorkDir $accountRoot -Env $accountEnv -Command 'go run ./cmd/account_service' -LogPath (Join-Path $LogDir 'account_service.log')
$processes += Start-QQTServiceWindow -PowerShellExe $PowerShellExe -Title "QQTang game_service : $($cfg.Game.ListenAddr)" -WorkDir $gameRoot -Env $gameEnv -Command 'go run ./cmd/game_service' -LogPath (Join-Path $LogDir 'game_service.log')
$processes += Start-QQTServiceWindow -PowerShellExe $PowerShellExe -Title "QQTang ds_manager_service : $($cfg.DSM.ListenAddr)" -WorkDir $dsmRoot -Env $dsmEnv -Command 'go run ./cmd/ds_manager_service' -LogPath (Join-Path $LogDir 'ds_manager_service.log')

$processes += Start-QQTServiceWindow -PowerShellExe $PowerShellExe -Title "QQTang room_service : $($cfg.Room.Host):$($cfg.Room.Port)" -WorkDir $roomRoot -Env $roomEnv -Command 'go run ./cmd/room_service' -LogPath (Join-Path $LogDir 'room_service.log')

Write-Host "Started QQTang services (profile=$Profile)"
Write-Host "  account_service:    http://$($cfg.Account.ListenAddr) pid=$($processes[0].Id)"
Write-Host "  game_service:       http://$($cfg.Game.ListenAddr) pid=$($processes[1].Id)"
Write-Host "  ds_manager_service: http://$($cfg.DSM.ListenAddr) pid=$($processes[2].Id)"
Write-Host "  room_service:       $($cfg.Room.Host):$($cfg.Room.Port) pid=$($processes[3].Id)"
Write-Host "Logs: $LogDir"
