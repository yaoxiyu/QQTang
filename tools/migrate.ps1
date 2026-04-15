param(
    [ValidateSet("dev", "test")]
    [string]$Env = "dev",

    [string]$ProjectPath = "",
    [switch]$SkipDb,
    [switch]$AccountOnly,
    [switch]$GameOnly
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
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 1
    }
    throw "Postgres not ready after ${TimeoutSeconds}s: $Container"
}

function Apply-SqlFile {
    param(
        [string]$Path,
        [string]$Container,
        [string]$User,
        [string]$Password,
        [string]$Database
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "SQL file not found: $Path"
    }
    Write-Host "  applying $(Split-Path -Leaf $Path) ..."
    Get-Content -LiteralPath $Path -Raw |
        docker exec -e PGPASSWORD=$Password -i $Container psql -v ON_ERROR_STOP=1 -U $User -d $Database
    if ($LASTEXITCODE -ne 0) {
        throw "Migration failed: $Path"
    }
}

# ---------- resolve paths ----------
$root = Resolve-ProjectPath $ProjectPath
$accountRoot = Join-Path $root "services\account_service"
$gameRoot    = Join-Path $root "services\game_service"

# ---------- env-dependent settings ----------
$envCfg = @{
    dev = @{
        AccountCompose   = Join-Path $accountRoot "docker-compose.dev.yml"
        GameCompose      = Join-Path $gameRoot    "docker-compose.dev.yml"
        AccountContainer = "qqtang_account_pg"
        AccountUser      = "qqtang"
        AccountPassword  = "qqtang_dev_pass"
        AccountDatabase  = "qqtang_account_dev"
        GameContainer    = "qqtang_game_pg"
        GameUser         = "qqtang_game"
        GamePassword     = "qqtang_game_dev_pass"
        GameDatabase     = "qqtang_game_dev"
    }
    test = @{
        AccountCompose   = Join-Path $accountRoot "docker-compose.test.yml"
        GameCompose      = Join-Path $gameRoot    "docker-compose.test.yml"
        AccountContainer = "qqtang_account_pg_test"
        AccountUser      = "qqtang_test"
        AccountPassword  = "qqtang_test_pass"
        AccountDatabase  = "qqtang_account_test"
        GameContainer    = "qqtang_game_pg_test"
        GameUser         = "qqtang_game_test"
        GamePassword     = "qqtang_game_test_pass"
        GameDatabase     = "qqtang_game_test"
    }
}

$cfg = $envCfg[$Env]

$runAccount = -not $GameOnly
$runGame    = -not $AccountOnly

# ---------- start containers ----------
if (-not $SkipDb) {
    if ($runAccount) {
        Write-Host "[migrate] Starting account postgres ($Env) ..."
        docker compose -f $cfg.AccountCompose up -d
        if ($LASTEXITCODE -ne 0) { throw "Failed to start account postgres" }
    }
    if ($runGame) {
        Write-Host "[migrate] Starting game postgres ($Env) ..."
        docker compose -f $cfg.GameCompose up -d
        if ($LASTEXITCODE -ne 0) { throw "Failed to start game postgres" }
    }

    if ($runAccount) { Wait-Postgres -Container $cfg.AccountContainer -User $cfg.AccountUser -Database $cfg.AccountDatabase }
    if ($runGame)    { Wait-Postgres -Container $cfg.GameContainer    -User $cfg.GameUser    -Database $cfg.GameDatabase }
}

# ---------- apply migrations ----------
if ($runAccount) {
    $accountMigrationDir = Join-Path $accountRoot "migrations"
    Write-Host "[migrate] account_service ($Env):"
    Get-ChildItem -LiteralPath $accountMigrationDir -Filter "*.sql" | Sort-Object Name | ForEach-Object {
        Apply-SqlFile `
            -Path      $_.FullName `
            -Container $cfg.AccountContainer `
            -User      $cfg.AccountUser `
            -Password  $cfg.AccountPassword `
            -Database  $cfg.AccountDatabase
    }
}

if ($runGame) {
    $gameMigrationDir = Join-Path $gameRoot "migrations"
    Write-Host "[migrate] game_service ($Env):"
    Get-ChildItem -LiteralPath $gameMigrationDir -Filter "*.sql" | Sort-Object Name | ForEach-Object {
        Apply-SqlFile `
            -Path      $_.FullName `
            -Container $cfg.GameContainer `
            -User      $cfg.GameUser `
            -Password  $cfg.GamePassword `
            -Database  $cfg.GameDatabase
    }
}

Write-Host ""
Write-Host "[migrate] Done ($Env)."

Pause