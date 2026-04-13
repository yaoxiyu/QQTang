param(
    [ValidateSet('dev', 'test')]
    [string]$Target = 'test'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir
$migrationFile = Join-Path $serviceRoot 'migrations\0001_phase20_matchmaking_and_progression_init.sql'

if (-not (Test-Path $migrationFile)) {
    throw "Migration file not found: $migrationFile"
}

$containerName = if ($Target -eq 'dev') { 'qqtang_game_pg' } else { 'qqtang_game_pg_test' }
$dbUser = if ($Target -eq 'dev') { 'qqtang_game' } else { 'qqtang_game_test' }
$dbName = if ($Target -eq 'dev') { 'qqtang_game_dev' } else { 'qqtang_game_test' }

Get-Content -LiteralPath $migrationFile -Raw | docker exec -i $containerName psql -U $dbUser -d $dbName
