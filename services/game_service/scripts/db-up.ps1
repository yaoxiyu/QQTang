param(
    [ValidateSet('dev', 'test')]
    [string]$Target = 'test'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir
$composeFile = if ($Target -eq 'dev') { 'docker-compose.dev.yml' } else { 'docker-compose.test.yml' }

Push-Location $serviceRoot
try {
    docker compose -f $composeFile up -d
}
finally {
    Pop-Location
}
