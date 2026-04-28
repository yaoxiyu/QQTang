param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [ValidateSet('all', 'account', 'game')]
    [string]$Service = 'all',
    [switch]$SkipDbUp,
    [switch]$NoBaseline
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

function Ensure-DatabaseExists {
    param($DbCfg)

    $sql = "SELECT 1 FROM pg_database WHERE datname = '$($DbCfg.Database)';"
    $exists = $sql | docker exec -e PGPASSWORD=$($DbCfg.Password) -i $($DbCfg.Container) psql -v ON_ERROR_STOP=1 -U $($DbCfg.User) -d 'postgres' -t -A
    if ($LASTEXITCODE -ne 0) { throw "failed to check db existence: $($DbCfg.Database)" }
    if (($exists | Select-Object -Last 1).Trim() -eq '1') {
        return
    }

    $createSql = "CREATE DATABASE ""$($DbCfg.Database)"";"
    Invoke-QQTPsql -Container $DbCfg.Container -User $DbCfg.User -Password $DbCfg.Password -Database 'postgres' -Sql $createSql
}

function Get-Scalar {
    param($DbCfg, [string]$Sql)

    $full = @"
$Sql
"@
    $result = $full | docker exec -e PGPASSWORD=$($DbCfg.Password) -i $($DbCfg.Container) psql -v ON_ERROR_STOP=1 -U $($DbCfg.User) -d $($DbCfg.Database) -t -A
    if ($LASTEXITCODE -ne 0) { throw "scalar query failed for container $($DbCfg.Container)" }
    return ($result | Select-Object -Last 1).Trim()
}

function Ensure-MigrationTable {
    param($DbCfg)

    $sql = @"
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    name TEXT PRIMARY KEY,
    checksum TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"@
    Invoke-QQTPsql -Container $DbCfg.Container -User $DbCfg.User -Password $DbCfg.Password -Database $DbCfg.Database -Sql $sql
}

function Get-QQTFileSha256 {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha.ComputeHash($stream)
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }

    return ([System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant())
}

function Apply-MigrationsForService {
    param(
        [string]$ServiceName,
        [string]$MigrationDir,
        $DbCfg,
        [switch]$NoBaseline
    )

    if (-not (Test-Path -LiteralPath $MigrationDir)) {
        throw "migration directory not found: $MigrationDir"
    }

    Write-Host "[db-migrate] $ServiceName -> $($DbCfg.Database)"

    $tableExists = Get-Scalar -DbCfg $DbCfg -Sql "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='schema_migrations');"
    $userTableCount = [int](Get-Scalar -DbCfg $DbCfg -Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';")

    Ensure-MigrationTable -DbCfg $DbCfg

    $migrationFiles = Get-ChildItem -LiteralPath $MigrationDir -Filter '*.sql' | Sort-Object Name

    if (($tableExists -eq 'f' -or $tableExists -eq 'false' -or [string]::IsNullOrWhiteSpace($tableExists)) -and $userTableCount -gt 0 -and -not $NoBaseline) {
        Write-Host "  baseline existing schema (legacy db without schema_migrations)"
        foreach ($file in $migrationFiles) {
            $checksum = Get-QQTFileSha256 -Path $file.FullName
            $insertSql = "INSERT INTO public.schema_migrations(name, checksum) VALUES ('$($file.Name)', '$checksum') ON CONFLICT (name) DO NOTHING;"
            Invoke-QQTPsql -Container $DbCfg.Container -User $DbCfg.User -Password $DbCfg.Password -Database $DbCfg.Database -Sql $insertSql
        }
    }

    $applied = @{}
    $appliedRows = "SELECT name FROM public.schema_migrations;" | docker exec -e PGPASSWORD=$($DbCfg.Password) -i $($DbCfg.Container) psql -v ON_ERROR_STOP=1 -U $($DbCfg.User) -d $($DbCfg.Database) -t -A
    if ($LASTEXITCODE -ne 0) {
        throw "failed to load applied migrations for $ServiceName"
    }
    foreach ($row in $appliedRows) {
        $name = $row.Trim()
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $applied[$name] = $true
        }
    }

    foreach ($file in $migrationFiles) {
        if ($applied.ContainsKey($file.Name)) {
            continue
        }

        Write-Host "  apply $($file.Name)"
        $sql = Get-Content -LiteralPath $file.FullName -Raw
        Invoke-QQTPsql -Container $DbCfg.Container -User $DbCfg.User -Password $DbCfg.Password -Database $DbCfg.Database -Sql $sql

        $checksum = Get-QQTFileSha256 -Path $file.FullName
        $insertSql = "INSERT INTO public.schema_migrations(name, checksum) VALUES ('$($file.Name)', '$checksum') ON CONFLICT (name) DO NOTHING;"
        Invoke-QQTPsql -Container $DbCfg.Container -User $DbCfg.User -Password $DbCfg.Password -Database $DbCfg.Database -Sql $insertSql
    }
}

$root = Resolve-QQTProjectRoot $ProjectPath
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $root

if (-not $SkipDbUp) {
    & (Join-Path $PSScriptRoot 'db-up.ps1') -Profile $Profile -ProjectPath $root
}

if ($Service -eq 'all' -or $Service -eq 'account') {
    Ensure-DatabaseExists -DbCfg $cfg.Account
    Apply-MigrationsForService -ServiceName 'account_service' -MigrationDir (Join-Path $root 'services\account_service\migrations') -DbCfg $cfg.Account -NoBaseline:$NoBaseline
}

if ($Service -eq 'all' -or $Service -eq 'game') {
    Ensure-DatabaseExists -DbCfg $cfg.Game
    Apply-MigrationsForService -ServiceName 'game_service' -MigrationDir (Join-Path $root 'services\game_service\migrations') -DbCfg $cfg.Game -NoBaseline:$NoBaseline
}

Write-Host "[db-migrate] done ($Profile, service=$Service)"
