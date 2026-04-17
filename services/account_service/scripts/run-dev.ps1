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

Set-DefaultEnv 'ACCOUNT_HTTP_LISTEN_ADDR' $cfg.Account.ListenAddr
Set-DefaultEnv 'ACCOUNT_POSTGRES_DSN' ("postgres://{0}:{1}@127.0.0.1:{2}/{3}?sslmode=disable" -f $cfg.Account.User, $cfg.Account.Password, $cfg.Account.Port, $cfg.Account.Database)
Set-DefaultEnv 'ACCOUNT_ACCESS_TOKEN_TTL_SECONDS' '900'
Set-DefaultEnv 'ACCOUNT_REFRESH_TOKEN_TTL_SECONDS' '1209600'
Set-DefaultEnv 'ACCOUNT_ROOM_TICKET_TTL_SECONDS' '60'
Set-DefaultEnv 'ACCOUNT_BATTLE_TICKET_TTL_SECONDS' '60'
Set-DefaultEnv 'ACCOUNT_TOKEN_SIGN_SECRET' 'replace_me_access_secret'
Set-DefaultEnv 'ACCOUNT_ROOM_TICKET_SIGN_SECRET' 'dev_room_ticket_secret'
Set-DefaultEnv 'ACCOUNT_GAME_SERVICE_BASE_URL' ("http://{0}" -f $cfg.Game.ListenAddr)
Set-DefaultEnv 'ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID' 'primary'
Set-DefaultEnv 'ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET' 'dev_internal_shared_secret'
Set-DefaultEnv 'ACCOUNT_ALLOW_MULTI_DEVICE' 'false'
Set-DefaultEnv 'ACCOUNT_GAME_INTERNAL_AUTH_MAX_SKEW_SECONDS' '60'
if ($LogSQL) {
    [Environment]::SetEnvironmentVariable('ACCOUNT_LOG_SQL', 'true')
} else {
    Set-DefaultEnv 'ACCOUNT_LOG_SQL' 'false'
}

Push-Location $serviceRoot
try {
    go run ./cmd/account_service
}
finally {
    Pop-Location
}
