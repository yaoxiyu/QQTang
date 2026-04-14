param(
    [ValidateSet('dev', 'test')]
    [string]$Target = 'test'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir
$migrationDir = Join-Path $serviceRoot 'migrations'

if (-not (Test-Path $migrationDir)) {
    throw "Migration directory not found: $migrationDir"
}

$containerName = if ($Target -eq 'dev') { 'qqtang_game_pg' } else { 'qqtang_game_pg_test' }
$dbUser = if ($Target -eq 'dev') { 'qqtang_game' } else { 'qqtang_game_test' }
$dbName = if ($Target -eq 'dev') { 'qqtang_game_dev' } else { 'qqtang_game_test' }
$dbPassword = if ($Target -eq 'dev') { 'qqtang_game_dev_pass' } else { 'qqtang_game_test_pass' }

Get-ChildItem -LiteralPath $migrationDir -Filter '*.sql' | Sort-Object Name | ForEach-Object {
    Write-Host "Applying migration $($_.Name)"
    Get-Content -LiteralPath $_.FullName -Raw | docker exec -e PGPASSWORD=$dbPassword -i $containerName psql -v ON_ERROR_STOP=1 -U $dbUser -d $dbName
}

Pause