param(
    [switch]$NoBootstrap
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

if (-not $NoBootstrap) {
    & (Join-Path $PSScriptRoot "db-up.ps1") -Target test
    & (Join-Path $PSScriptRoot "db-reset-test-schema.ps1")
    & (Join-Path $PSScriptRoot "db-apply-migration.ps1") -Target test
}

$env:ACCOUNT_SERVICE_TEST_POSTGRES_DSN = "postgres://qqtang_test:qqtang_test_pass@127.0.0.1:54330/qqtang_account_test?sslmode=disable"
Push-Location $root
try {
    go test ./internal/httpapi -run Test -count=1 -v
}
finally {
    Pop-Location
}
