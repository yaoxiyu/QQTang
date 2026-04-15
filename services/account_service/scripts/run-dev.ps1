param(
    [string]$ListenAddr = "127.0.0.1:18080",
    [switch]$LogSQL
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

$env:ACCOUNT_HTTP_LISTEN_ADDR = $ListenAddr
$env:ACCOUNT_POSTGRES_DSN = "postgres://qqtang:qqtang_dev_pass@127.0.0.1:54329/qqtang_account_dev?sslmode=disable"
$env:ACCOUNT_ACCESS_TOKEN_TTL_SECONDS = "900"
$env:ACCOUNT_REFRESH_TOKEN_TTL_SECONDS = "1209600"
$env:ACCOUNT_ROOM_TICKET_TTL_SECONDS = "60"
$env:ACCOUNT_BATTLE_TICKET_TTL_SECONDS = "60"
$env:ACCOUNT_TOKEN_SIGN_SECRET = "replace_me_access_secret"
$env:ACCOUNT_ROOM_TICKET_SIGN_SECRET = "dev_room_ticket_secret"
$env:ACCOUNT_GAME_SERVICE_BASE_URL = "http://127.0.0.1:18081"
$env:ACCOUNT_GAME_INTERNAL_AUTH_KEY_ID = "primary"
$env:ACCOUNT_GAME_INTERNAL_AUTH_SHARED_SECRET = "dev_internal_shared_secret"
$env:ACCOUNT_ALLOW_MULTI_DEVICE = "false"
$env:ACCOUNT_LOG_SQL = if ($LogSQL) { "true" } else { "false" }

Push-Location $root
try {
    go run ./cmd/account_service
}
finally {
    Pop-Location
}

Pause