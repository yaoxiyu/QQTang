param(
    [ValidateSet('dev', 'test')]
    [string]$Target = 'dev',
    [switch]$Recreate
)

$serviceRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Resolve-Path (Join-Path $serviceRoot '..\..')

& (Join-Path $projectRoot 'tools\db-up.ps1') -Profile $Target -ProjectPath $projectRoot -GameOnly -Recreate:$Recreate
