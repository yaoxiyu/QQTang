param(
    [ValidateSet('dev', 'test')]
    [string]$Target = 'dev',
    [string]$Migration = ''
)

if (-not [string]::IsNullOrWhiteSpace($Migration)) {
    Write-Host '[notice] -Migration is no longer used; all pending migrations are applied in order.' -ForegroundColor Yellow
}

$serviceRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Resolve-Path (Join-Path $serviceRoot '..\..')

& (Join-Path $projectRoot 'tools\db-migrate.ps1') -Profile $Target -ProjectPath $projectRoot -Service account
