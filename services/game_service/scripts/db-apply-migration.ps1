param(
    [ValidateSet('dev', 'test')]
    [string]$Target = 'test'
)

$serviceRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Resolve-Path (Join-Path $serviceRoot '..\..')

& (Join-Path $projectRoot 'tools\db-migrate.ps1') -Profile $Target -ProjectPath $projectRoot -Service game
