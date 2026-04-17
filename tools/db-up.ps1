param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [switch]$Recreate,
    [switch]$AccountOnly,
    [switch]$GameOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

$root = Resolve-QQTProjectRoot $ProjectPath
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $root
$runAccount = -not $GameOnly
$runGame = -not $AccountOnly

if ($Recreate) {
    if ($runAccount) {
        docker compose -f $cfg.Account.ComposeFile down -v
        if ($LASTEXITCODE -ne 0) { throw 'Failed to recreate account postgres container' }
    }
    if ($runGame) {
        docker compose -f $cfg.Game.ComposeFile down -v
        if ($LASTEXITCODE -ne 0) { throw 'Failed to recreate game postgres container' }
    }
}

if ($runAccount) {
    Write-Host "[db-up] account_service postgres ($Profile)"
    docker compose -f $cfg.Account.ComposeFile up -d
    if ($LASTEXITCODE -ne 0) { throw 'Failed to start account_service postgres' }
    Wait-QQTPostgres -Container $cfg.Account.Container -User $cfg.Account.User -Database $cfg.Account.Database
}
if ($runGame) {
    Write-Host "[db-up] game_service postgres ($Profile)"
    docker compose -f $cfg.Game.ComposeFile up -d
    if ($LASTEXITCODE -ne 0) { throw 'Failed to start game_service postgres' }
    Wait-QQTPostgres -Container $cfg.Game.Container -User $cfg.Game.User -Database $cfg.Game.Database
}

Write-Host "[db-up] done ($Profile)"
