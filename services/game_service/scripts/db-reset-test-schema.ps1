param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceRoot = Split-Path -Parent $scriptDir
$migrationScript = Join-Path $scriptDir 'db-apply-migration.ps1'

docker exec -i qqtang_game_pg_test psql -U qqtang_game_test -d qqtang_game_test -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
& $migrationScript -Target test
