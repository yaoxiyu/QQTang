param(
    [ValidateSet('dev', 'test')]
    [string]$Env = 'dev',
    [string]$ProjectPath = '',
    [switch]$SkipDb,
    [switch]$AccountOnly,
    [switch]$GameOnly
)

Write-Host '[deprecated] tools/migrate.ps1 -> use tools/db-migrate.ps1' -ForegroundColor Yellow

$service = 'all'
if ($AccountOnly -and -not $GameOnly) { $service = 'account' }
if ($GameOnly -and -not $AccountOnly) { $service = 'game' }

& (Join-Path $PSScriptRoot 'db-migrate.ps1') `
    -Profile $Env `
    -ProjectPath $ProjectPath `
    -Service $service `
    -SkipDbUp:$SkipDb
