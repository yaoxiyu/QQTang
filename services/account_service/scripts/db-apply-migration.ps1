param(
    [ValidateSet("dev", "test")]
    [string]$Target = "dev",
    [string]$Migration = "0001_account_auth_init.sql"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$migrationPath = Join-Path (Join-Path $root "migrations") $Migration

if (-not (Test-Path $migrationPath)) {
    throw "Migration file not found: $migrationPath"
}

if ($Target -eq "dev") {
    $container = "qqtang_account_pg"
    $database = "qqtang_account_dev"
    $user = "qqtang"
    $password = "qqtang_dev_pass"
}
else {
    $container = "qqtang_account_pg_test"
    $database = "qqtang_account_test"
    $user = "qqtang_test"
    $password = "qqtang_test_pass"
}

Get-Content -Raw $migrationPath | docker exec -e PGPASSWORD=$password -i $container psql -U $user -d $database
