param(
    [string]$Dsn = 'postgres://qqtang_game_test:qqtang_game_test_pass@127.0.0.1:54332/qqtang_game_test?sslmode=disable'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir

& (Join-Path $scriptDir 'db-up.ps1') -Target test
& (Join-Path $scriptDir 'db-reset-test-schema.ps1')

Push-Location $serviceRoot
try {
    $env:GAME_TEST_POSTGRES_DSN = $Dsn
    go test ./...
}
finally {
    Pop-Location
}
