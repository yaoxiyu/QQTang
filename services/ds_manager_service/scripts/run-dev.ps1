param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$EnvFile = ''
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir
. (Join-Path $serviceRoot '..\..\tools\lib\dev_common.ps1')

function Set-DefaultEnv {
    param([string]$Key, [string]$Value)
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Key))) {
        [Environment]::SetEnvironmentVariable($Key, $Value)
    }
}

$projectRoot = Resolve-QQTProjectRoot ''
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $projectRoot
$resolvedEnvFile = Get-QQTEnvFilePath -ServiceRoot $serviceRoot -Profile $Profile -EnvFile $EnvFile
Import-QQTDotEnv -EnvFile $resolvedEnvFile

Set-DefaultEnv 'DSM_HTTP_ADDR' $cfg.DSM.ListenAddr
Set-DefaultEnv 'DSM_GODOT_EXECUTABLE' (Join-Path $projectRoot 'godot_binary\Godot_console.exe')
Set-DefaultEnv 'DSM_PROJECT_ROOT' $projectRoot
Set-DefaultEnv 'DSM_BATTLE_SCENE_PATH' 'res://scenes/network/dedicated_server_scene.tscn'
Set-DefaultEnv 'DSM_BATTLE_TICKET_SECRET' 'dev_battle_ticket_secret'
Set-DefaultEnv 'DSM_BATTLE_LOG_DIR' ''
Set-DefaultEnv 'DSM_DS_HOST' $cfg.Room.Host
Set-DefaultEnv 'DSM_PORT_RANGE_START' '19010'
Set-DefaultEnv 'DSM_PORT_RANGE_END' '19050'
Set-DefaultEnv 'DSM_READY_TIMEOUT_SEC' '15'
Set-DefaultEnv 'DSM_IDLE_REAP_TIMEOUT_SEC' '300'
Set-DefaultEnv 'DSM_INTERNAL_AUTH_KEY_ID' 'primary'
Set-DefaultEnv 'DSM_INTERNAL_AUTH_SHARED_SECRET' 'dev_internal_shared_secret'
Set-DefaultEnv 'DSM_INTERNAL_AUTH_MAX_SKEW_SECONDS' '60'

Push-Location $serviceRoot
try {
    go run ./cmd/ds_manager_service
}
finally {
    Pop-Location
}
