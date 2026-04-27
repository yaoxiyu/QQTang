param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [string]$ComposeFile = '',
    [string]$GodotExecutable = '',
    [switch]$SkipPrepare,
    [switch]$SkipMigration,
    [switch]$SkipBuild,
    [switch]$Recreate,
    [switch]$NoBaseline,
    [switch]$Pull,
    [switch]$Logs
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

function Invoke-QQTDockerCompose {
    param(
        [string]$ComposeFile,
        [string[]]$ComposeArgs
    )

    & docker @('compose', '-f', $ComposeFile) @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed: $($ComposeArgs -join ' ')"
    }
}

function Get-QQTDockerDbConfig {
    param([ValidateSet('dev', 'test')][string]$Profile)

    if ($Profile -eq 'test') {
        return @{
            Account = @{
                Service = 'account_postgres_test'
                User = 'qqtang_test'
                Password = 'qqtang_test_pass'
                Database = 'qqtang_account_test'
            }
            Game = @{
                Service = 'game_postgres_test'
                User = 'qqtang_game_test'
                Password = 'qqtang_game_test_pass'
                Database = 'qqtang_game_test'
            }
        }
    }

    return @{
        Account = @{
            Service = 'account_postgres'
            User = 'qqtang'
            Password = 'qqtang_dev_pass'
            Database = 'qqtang_account_dev'
        }
        Game = @{
            Service = 'game_postgres'
            User = 'qqtang_game'
            Password = 'qqtang_game_dev_pass'
            Database = 'qqtang_game_dev'
        }
    }
}

function Resolve-QQTDockerGodotExecutable {
    param([string]$GodotExecutable)

    if (-not [string]::IsNullOrWhiteSpace($GodotExecutable)) {
        if (Test-Path -LiteralPath $GodotExecutable) {
            return (Resolve-Path -LiteralPath $GodotExecutable).Path
        }

        $cmd = Get-Command $GodotExecutable -ErrorAction SilentlyContinue
        if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
            return $cmd.Source
        }

        throw "Godot executable not found: $GodotExecutable"
    }

    $cmd = Get-Command 'Godot_console.exe' -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
        return $cmd.Source
    }

    $defaultPath = 'D:\Godot\Godot_console.exe'
    if (Test-Path -LiteralPath $defaultPath) {
        return $defaultPath
    }

    throw 'Godot executable not found. Pass -GodotExecutable D:\path\Godot_console.exe'
}

function Wait-QQTComposePostgres {
    param(
        [string]$ComposeFile,
        $DbCfg,
        [int]$TimeoutSeconds = 45
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        & docker @('compose', '-f', $ComposeFile, 'exec', '-T', $DbCfg.Service, 'pg_isready', '-U', $DbCfg.User, '-d', $DbCfg.Database) *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "Postgres is not ready: $($DbCfg.Service)"
}

function Invoke-QQTComposePsql {
    param(
        [string]$ComposeFile,
        $DbCfg,
        [string]$Database,
        [string]$Sql
    )

    $dockerArgs = @(
        'compose', '-f', $ComposeFile,
        'exec', '-T',
        '-e', "PGPASSWORD=$($DbCfg.Password)",
        $DbCfg.Service,
        'psql', '-v', 'ON_ERROR_STOP=1',
        '-U', $DbCfg.User,
        '-d', $Database
    )
    $Sql | docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "psql execution failed in compose service: $($DbCfg.Service)"
    }
}

function Get-QQTComposeScalar {
    param(
        [string]$ComposeFile,
        $DbCfg,
        [string]$Sql
    )

    $dockerArgs = @(
        'compose', '-f', $ComposeFile,
        'exec', '-T',
        '-e', "PGPASSWORD=$($DbCfg.Password)",
        $DbCfg.Service,
        'psql', '-v', 'ON_ERROR_STOP=1',
        '-U', $DbCfg.User,
        '-d', $DbCfg.Database,
        '-t', '-A'
    )
    $result = $Sql | docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "scalar query failed in compose service: $($DbCfg.Service)"
    }
    return ($result | Select-Object -Last 1).Trim()
}

function Get-QQTComposeRows {
    param(
        [string]$ComposeFile,
        $DbCfg,
        [string]$Sql
    )

    $dockerArgs = @(
        'compose', '-f', $ComposeFile,
        'exec', '-T',
        '-e', "PGPASSWORD=$($DbCfg.Password)",
        $DbCfg.Service,
        'psql', '-v', 'ON_ERROR_STOP=1',
        '-U', $DbCfg.User,
        '-d', $DbCfg.Database,
        '-t', '-A'
    )
    $result = $Sql | docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "row query failed in compose service: $($DbCfg.Service)"
    }
    return $result
}

function Ensure-QQTComposeDatabaseExists {
    param(
        [string]$ComposeFile,
        $DbCfg
    )

    $existsSql = "SELECT 1 FROM pg_database WHERE datname = '$($DbCfg.Database)';"
    $dockerArgs = @(
        'compose', '-f', $ComposeFile,
        'exec', '-T',
        '-e', "PGPASSWORD=$($DbCfg.Password)",
        $DbCfg.Service,
        'psql', '-v', 'ON_ERROR_STOP=1',
        '-U', $DbCfg.User,
        '-d', 'postgres',
        '-t', '-A'
    )
    $exists = $existsSql | docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "failed to check database: $($DbCfg.Database)"
    }
    if (($exists | Select-Object -Last 1).Trim() -eq '1') {
        return
    }

    Invoke-QQTComposePsql -ComposeFile $ComposeFile -DbCfg $DbCfg -Database 'postgres' -Sql "CREATE DATABASE ""$($DbCfg.Database)"";"
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

function Invoke-QQTComposeMigrations {
    param(
        [string]$ComposeFile,
        [string]$ServiceName,
        [string]$MigrationDir,
        $DbCfg,
        [switch]$NoBaseline
    )

    if (-not (Test-Path -LiteralPath $MigrationDir)) {
        throw "migration directory not found: $MigrationDir"
    }

    Write-Host "[docker-services] migrate $ServiceName"
    Ensure-QQTComposeDatabaseExists -ComposeFile $ComposeFile -DbCfg $DbCfg
    $tableExists = Get-QQTComposeScalar -ComposeFile $ComposeFile -DbCfg $DbCfg -Sql "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='schema_migrations');"
    $userTableCount = [int](Get-QQTComposeScalar -ComposeFile $ComposeFile -DbCfg $DbCfg -Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';")
    Invoke-QQTComposePsql -ComposeFile $ComposeFile -DbCfg $DbCfg -Database $DbCfg.Database -Sql @"
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    name TEXT PRIMARY KEY,
    checksum TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"@

    $migrationFiles = Get-ChildItem -LiteralPath $MigrationDir -Filter '*.sql' | Sort-Object Name
    if (($tableExists -eq 'f' -or $tableExists -eq 'false' -or [string]::IsNullOrWhiteSpace($tableExists)) -and $userTableCount -gt 0 -and -not $NoBaseline) {
        Write-Host "  baseline existing schema"
        foreach ($file in $migrationFiles) {
            $checksum = Get-QQTFileSha256 -Path $file.FullName
            $markSql = "INSERT INTO public.schema_migrations(name, checksum) VALUES ('$($file.Name)', '$checksum') ON CONFLICT (name) DO NOTHING;"
            Invoke-QQTComposePsql -ComposeFile $ComposeFile -DbCfg $DbCfg -Database $DbCfg.Database -Sql $markSql
        }
    }

    $applied = @{}
    $rows = Get-QQTComposeRows -ComposeFile $ComposeFile -DbCfg $DbCfg -Sql 'SELECT name FROM public.schema_migrations;'
    foreach ($row in $rows) {
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
        Invoke-QQTComposePsql -ComposeFile $ComposeFile -DbCfg $DbCfg -Database $DbCfg.Database -Sql $sql

        $checksum = Get-QQTFileSha256 -Path $file.FullName
        $markSql = "INSERT INTO public.schema_migrations(name, checksum) VALUES ('$($file.Name)', '$checksum') ON CONFLICT (name) DO NOTHING;"
        Invoke-QQTComposePsql -ComposeFile $ComposeFile -DbCfg $DbCfg -Database $DbCfg.Database -Sql $markSql
    }
}

$root = Resolve-QQTProjectRoot $ProjectPath
if ([string]::IsNullOrWhiteSpace($ComposeFile)) {
    $ComposeFile = Join-Path $root "deploy\docker\docker-compose.$Profile.yml"
} else {
    $ComposeFile = (Resolve-Path -LiteralPath $ComposeFile).Path
}

if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "compose file not found: $ComposeFile"
}

$db = Get-QQTDockerDbConfig -Profile $Profile
$resolvedGodotExecutable = Resolve-QQTDockerGodotExecutable -GodotExecutable $GodotExecutable

Push-Location $root
try {
    if (-not $SkipPrepare) {
        & (Join-Path $root 'tests\scripts\check_gdscript_syntax.ps1') -GodotExe $resolvedGodotExecutable -ProjectPath $root
        if ($LASTEXITCODE -ne 0) {
            throw 'GDScript syntax preflight failed'
        }

        & (Join-Path $root 'scripts\content\generate_room_manifest.ps1') -ProjectPath $root -GodotExecutable $resolvedGodotExecutable
        if ($LASTEXITCODE -ne 0) {
            throw 'room manifest generation failed'
        }
    }

    if ($Recreate) {
        Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @('down', '-v')
    }

    if ($Pull) {
        Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @('pull', '--ignore-buildable')
    }

    Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @('up', '-d', $db.Account.Service, $db.Game.Service)
    Wait-QQTComposePostgres -ComposeFile $ComposeFile -DbCfg $db.Account
    Wait-QQTComposePostgres -ComposeFile $ComposeFile -DbCfg $db.Game

    if (-not $SkipMigration) {
        Invoke-QQTComposeMigrations `
            -ComposeFile $ComposeFile `
            -ServiceName 'account_service' `
            -MigrationDir (Join-Path $root 'services\account_service\migrations') `
            -DbCfg $db.Account `
            -NoBaseline:$NoBaseline
        Invoke-QQTComposeMigrations `
            -ComposeFile $ComposeFile `
            -ServiceName 'game_service' `
            -MigrationDir (Join-Path $root 'services\game_service\migrations') `
            -DbCfg $db.Game `
            -NoBaseline:$NoBaseline
    }

    if (-not $SkipBuild) {
        Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @('build')
    }

    Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @(
        'up', '-d',
        'ds_manager_service',
        'game_service',
        'account_service',
        'room_service'
    )

    Write-Host "[docker-services] started ($Profile)"
    Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @('ps')

    if ($Logs) {
        Invoke-QQTDockerCompose -ComposeFile $ComposeFile -ComposeArgs @('logs', '-f')
    }
}
finally {
    Pop-Location
}
