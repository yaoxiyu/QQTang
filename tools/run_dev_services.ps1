param(
    [string]$ProjectPath = "",
    [string]$PowerShellExe = "powershell",
    [switch]$SkipDb,
    [switch]$SkipMigration,
    [switch]$LogSQL,
    [string]$AccountListenAddr = "127.0.0.1:18080",
    [string]$GameListenAddr = "127.0.0.1:18081",
    [string]$AccountPostgresPort = "54329",
    [string]$GamePostgresPort = "54331",
    [string]$TokenSecret = "replace_me_access_secret",
    [string]$RoomTicketSecret = "dev_room_ticket_secret",
    [string]$InternalSharedSecret = "dev_game_internal_secret",
    [string]$DefaultDSHost = "127.0.0.1",
    [int]$DefaultDSPort = 9000
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectPath {
    param([string]$InputPath)
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        return (Resolve-Path -LiteralPath $InputPath).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Wait-Postgres {
    param(
        [string]$Container,
        [string]$User,
        [string]$Database,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        docker exec $Container pg_isready -U $User -d $Database *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 1
    }
    throw "Postgres is not ready: $Container"
}

function Apply-Migration {
    param(
        [string]$MigrationPath,
        [string]$Container,
        [string]$User,
        [string]$Password,
        [string]$Database
    )

    if (-not (Test-Path -LiteralPath $MigrationPath)) {
        throw "Migration file not found: $MigrationPath"
    }
    Get-Content -LiteralPath $MigrationPath -Raw | docker exec -e PGPASSWORD=$Password -i $Container psql -U $User -d $Database
    if ($LASTEXITCODE -ne 0) {
        throw "Migration failed: $MigrationPath"
    }
}

function Quote-PS {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Start-ServiceWindow {
    param(
        [string]$Title,
        [string]$WorkDir,
        [hashtable]$Env,
        [string]$Command
    )

    $envLines = @()
    foreach ($key in $Env.Keys) {
        $envLines += "`$env:$key = $(Quote-PS ([string]$Env[$key]))"
    }
    $script = @(
        "`$Host.UI.RawUI.WindowTitle = $(Quote-PS $Title)",
        $envLines,
        "Set-Location -LiteralPath $(Quote-PS $WorkDir)",
        $Command
    ) -join "; "

    return Start-Process -FilePath $PowerShellExe -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-Command", $script
    ) -PassThru
}

$root = Resolve-ProjectPath $ProjectPath
$accountRoot = Join-Path $root "services\account_service"
$gameRoot = Join-Path $root "services\game_service"
$accountCompose = Join-Path $accountRoot "docker-compose.dev.yml"
$gameCompose = Join-Path $gameRoot "docker-compose.dev.yml"

if (-not $SkipDb) {
    docker compose -f $accountCompose up -d
    if ($LASTEXITCODE -ne 0) { throw "Failed to start account_service postgres" }
    docker compose -f $gameCompose up -d
    if ($LASTEXITCODE -ne 0) { throw "Failed to start game_service postgres" }

    Wait-Postgres -Container "qqtang_account_pg" -User "qqtang" -Database "qqtang_account_dev"
    Wait-Postgres -Container "qqtang_game_pg" -User "qqtang_game" -Database "qqtang_game_dev"
}

if (-not $SkipMigration) {
    Apply-Migration `
        -MigrationPath (Join-Path $accountRoot "migrations\0001_account_auth_init.sql") `
        -Container "qqtang_account_pg" `
        -User "qqtang" `
        -Password "qqtang_dev_pass" `
        -Database "qqtang_account_dev"

    Apply-Migration `
        -MigrationPath (Join-Path $gameRoot "migrations\0001_phase20_matchmaking_and_progression_init.sql") `
        -Container "qqtang_game_pg" `
        -User "qqtang_game" `
        -Password "qqtang_game_dev_pass" `
        -Database "qqtang_game_dev"
}

$sharedEnv = @{
    "GAME_INTERNAL_SHARED_SECRET" = $InternalSharedSecret
}

$accountEnv = $sharedEnv.Clone()
$accountEnv["ACCOUNT_HTTP_LISTEN_ADDR"] = $AccountListenAddr
$accountEnv["ACCOUNT_POSTGRES_DSN"] = "postgres://qqtang:qqtang_dev_pass@127.0.0.1:$AccountPostgresPort/qqtang_account_dev?sslmode=disable"
$accountEnv["ACCOUNT_ACCESS_TOKEN_TTL_SECONDS"] = "900"
$accountEnv["ACCOUNT_REFRESH_TOKEN_TTL_SECONDS"] = "1209600"
$accountEnv["ACCOUNT_ROOM_TICKET_TTL_SECONDS"] = "60"
$accountEnv["ACCOUNT_TOKEN_SIGN_SECRET"] = $TokenSecret
$accountEnv["ACCOUNT_ROOM_TICKET_SIGN_SECRET"] = $RoomTicketSecret
$accountEnv["ACCOUNT_GAME_SERVICE_BASE_URL"] = "http://$GameListenAddr"
$accountEnv["ACCOUNT_GAME_INTERNAL_SHARED_SECRET"] = $InternalSharedSecret
$accountEnv["ACCOUNT_ALLOW_MULTI_DEVICE"] = "false"
$accountEnv["ACCOUNT_LOG_SQL"] = if ($LogSQL) { "true" } else { "false" }

$gameEnv = $sharedEnv.Clone()
$gameEnv["GAME_HTTP_ADDR"] = $GameListenAddr
$gameEnv["GAME_POSTGRES_DSN"] = "postgres://qqtang_game:qqtang_game_dev_pass@127.0.0.1:$GamePostgresPort/qqtang_game_dev?sslmode=disable"
$gameEnv["GAME_JWT_SHARED_SECRET"] = $TokenSecret
$gameEnv["GAME_DEFAULT_DS_HOST"] = $DefaultDSHost
$gameEnv["GAME_DEFAULT_DS_PORT"] = [string]$DefaultDSPort
$gameEnv["GAME_QUEUE_HEARTBEAT_TTL_SECONDS"] = "30"
$gameEnv["GAME_CAPTAIN_DEADLINE_SECONDS"] = "15"
$gameEnv["GAME_COMMIT_DEADLINE_SECONDS"] = "45"
$gameEnv["GAME_LOG_SQL"] = if ($LogSQL) { "true" } else { "false" }

$processes = @()
$processes += Start-ServiceWindow -Title "QQTang account_service : $AccountListenAddr" -WorkDir $accountRoot -Env $accountEnv -Command "go run ./cmd/account_service"
$processes += Start-ServiceWindow -Title "QQTang game_service : $GameListenAddr" -WorkDir $gameRoot -Env $gameEnv -Command "go run ./cmd/game_service"

Write-Host "Started QQTang dev services:"
Write-Host "  account_service: http://$AccountListenAddr pid=$($processes[0].Id)"
Write-Host "  game_service:    http://$GameListenAddr pid=$($processes[1].Id)"
Write-Host "  account postgres: 127.0.0.1:$AccountPostgresPort"
Write-Host "  game postgres:    127.0.0.1:$GamePostgresPort"
Write-Host ""
Write-Host "Close the spawned PowerShell windows to stop the Go services."
