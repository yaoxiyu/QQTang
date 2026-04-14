param(
    [ValidateSet('test', 'dev')]
    [string]$Target = 'test',

    [switch]$Force
)

$containerName = if ($Target -eq 'dev') { 'qqtang_game_pg' } else { 'qqtang_game_pg_test' }
$dbUser = if ($Target -eq 'dev') { 'qqtang_game' } else { 'qqtang_game_test' }
$dbName = if ($Target -eq 'dev') { 'qqtang_game_dev' } else { 'qqtang_game_test' }
$dbPassword = if ($Target -eq 'dev') { 'qqtang_game_dev_pass' } else { 'qqtang_game_test_pass' }

if ($Target -eq 'dev' -and -not $Force) {
    throw "Refusing to clean dev data without -Force. This script is for non-production cleanup before constraint migrations."
}

$sql = @"
BEGIN;

TRUNCATE TABLE
    reward_ledger_entries,
    player_match_results,
    match_results,
    season_rating_snapshots,
    career_summaries,
    matchmaking_assignment_members,
    matchmaking_queue_entries,
    matchmaking_assignments,
    season_definitions
RESTART IDENTITY CASCADE;

COMMIT;
"@

Write-Host "Cleaning $Target game_service database data in container $containerName..."
$sql | docker exec -e PGPASSWORD=$dbPassword -i $containerName psql -v ON_ERROR_STOP=1 -U $dbUser -d $dbName
Write-Host "Done. Re-apply migrations if the next constraint migration expects a fresh schema state."
