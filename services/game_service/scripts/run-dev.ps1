param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$EnvFile = '',
    [switch]$LogSQL
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

Set-DefaultEnv 'GAME_HTTP_ADDR' $cfg.Game.ListenAddr
Set-DefaultEnv 'GAME_POSTGRES_DSN' ("postgres://{0}:{1}@127.0.0.1:{2}/{3}?sslmode=disable" -f $cfg.Game.User, $cfg.Game.Password, $cfg.Game.Port, $cfg.Game.Database)
Set-DefaultEnv 'GAME_JWT_SHARED_SECRET' 'replace_me_access_secret'
Set-DefaultEnv 'GAME_INTERNAL_AUTH_KEY_ID' 'primary'
Set-DefaultEnv 'GAME_INTERNAL_AUTH_SHARED_SECRET' 'dev_internal_shared_secret'
Set-DefaultEnv 'GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS' '60'
Set-DefaultEnv 'GAME_DEFAULT_DS_HOST' $cfg.Room.Host
Set-DefaultEnv 'GAME_DEFAULT_DS_PORT' ([string]$cfg.Room.Port)
Set-DefaultEnv 'GAME_DS_MANAGER_URL' ("http://{0}" -f $cfg.DSM.ListenAddr)
Set-DefaultEnv 'GAME_QUEUE_HEARTBEAT_TTL_SECONDS' '30'
Set-DefaultEnv 'GAME_CAPTAIN_DEADLINE_SECONDS' '15'
Set-DefaultEnv 'GAME_COMMIT_DEADLINE_SECONDS' '45'
if ($LogSQL) {
    [Environment]::SetEnvironmentVariable('GAME_LOG_SQL', 'true')
} else {
    Set-DefaultEnv 'GAME_LOG_SQL' 'false'
}

Push-Location $serviceRoot
try {
    go run ./cmd/game_service
}
finally {
    Pop-Location
}
