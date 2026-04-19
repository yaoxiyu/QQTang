param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [string]$EnvFile = '',
    [string]$GodotExecutable = 'Godot_console.exe',
    [string]$LogFile = '',
    [string]$RoomHost = '',
    [int]$RoomPort = 0,
    [string]$RoomTicketSecret = ''
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$networkRoot = Split-Path -Parent $scriptDir
. (Join-Path $networkRoot '..\tools\lib\dev_common.ps1')

function Set-DefaultEnv {
    param([string]$Key, [string]$Value)
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Key))) {
        [Environment]::SetEnvironmentVariable($Key, $Value)
    }
}

$root = Resolve-QQTProjectRoot $ProjectPath
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $root
$resolvedEnvFile = Get-QQTEnvFilePath -ServiceRoot $networkRoot -Profile $Profile -EnvFile $EnvFile
Import-QQTDotEnv -EnvFile $resolvedEnvFile

if ([string]::IsNullOrWhiteSpace($RoomHost)) {
    $RoomHost = $cfg.Room.Host
}
if ($RoomPort -le 0) {
    $RoomPort = [int]$cfg.Room.Port
}
if ([string]::IsNullOrWhiteSpace($RoomTicketSecret)) {
    $RoomTicketSecret = 'dev_room_ticket_secret'
}

Set-DefaultEnv 'GAME_SERVICE_HOST' (($cfg.Game.ListenAddr -split ':')[0])
Set-DefaultEnv 'GAME_SERVICE_PORT' (($cfg.Game.ListenAddr -split ':')[1])
Set-DefaultEnv 'GAME_INTERNAL_AUTH_KEY_ID' 'primary'
Set-DefaultEnv 'GAME_INTERNAL_AUTH_SHARED_SECRET' 'dev_internal_shared_secret'

Push-Location $root
try {
    $args = @('--headless')
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        $args += @('--log-file', $LogFile)
    }
    $args += @(
        '--path', $root,
        'res://scenes/network/dedicated_server_scene.tscn',
        '--',
        '--qqt-room-port', [string]$RoomPort,
        '--qqt-room-host', $RoomHost,
        '--qqt-room-ticket-secret', $RoomTicketSecret
    )
    & $GodotExecutable @args
}
finally {
    Pop-Location
}
