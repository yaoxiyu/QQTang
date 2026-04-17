Set-StrictMode -Version Latest

function Resolve-QQTProjectRoot {
    param([string]$ProjectPath)

    if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
        return (Resolve-Path -LiteralPath $ProjectPath).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\.." )).Path
}

function Import-QQTDotEnv {
    param([string]$EnvFile)

    if ([string]::IsNullOrWhiteSpace($EnvFile) -or -not (Test-Path -LiteralPath $EnvFile)) {
        return
    }

    Get-Content -LiteralPath $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#') -or ($line -notmatch '=')) {
            return
        }
        $parts = $line.Split('=', 2)
        $key = $parts[0].Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            return
        }
        $value = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        [Environment]::SetEnvironmentVariable($key, $value)
    }
}

function Get-QQTEnvFilePath {
    param(
        [string]$ServiceRoot,
        [ValidateSet('dev', 'test')]
        [string]$Profile = 'dev',
        [string]$EnvFile = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($EnvFile)) {
        return $EnvFile
    }

    $profileFile = Join-Path $ServiceRoot (".env.{0}" -f $Profile)
    if (Test-Path -LiteralPath $profileFile) {
        return $profileFile
    }

    return Join-Path $ServiceRoot '.env'
}

function Get-QQTProfileConfig {
    param(
        [ValidateSet('dev', 'test')]
        [string]$Profile,
        [string]$Root
    )

    $accountRoot = Join-Path $Root 'services\account_service'
    $gameRoot = Join-Path $Root 'services\game_service'

    if ($Profile -eq 'test') {
        return @{
            Profile = 'test'
            Account = @{
                ComposeFile = Join-Path $accountRoot 'docker-compose.test.yml'
                Container = 'qqtang_account_pg_test'
                User = 'qqtang_test'
                Password = 'qqtang_test_pass'
                Database = 'qqtang_account_test'
                Port = 54330
                ListenAddr = '127.0.0.1:28080'
            }
            Game = @{
                ComposeFile = Join-Path $gameRoot 'docker-compose.test.yml'
                Container = 'qqtang_game_pg_test'
                User = 'qqtang_game_test'
                Password = 'qqtang_game_test_pass'
                Database = 'qqtang_game_test'
                Port = 54332
                ListenAddr = '127.0.0.1:28081'
            }
            DSM = @{
                ListenAddr = '127.0.0.1:28090'
            }
            Room = @{
                Host = '127.0.0.1'
                Port = 19000
            }
        }
    }

    return @{
        Profile = 'dev'
        Account = @{
            ComposeFile = Join-Path $accountRoot 'docker-compose.dev.yml'
            Container = 'qqtang_account_pg'
            User = 'qqtang'
            Password = 'qqtang_dev_pass'
            Database = 'qqtang_account_dev'
            Port = 54329
            ListenAddr = '127.0.0.1:18080'
        }
        Game = @{
            ComposeFile = Join-Path $gameRoot 'docker-compose.dev.yml'
            Container = 'qqtang_game_pg'
            User = 'qqtang_game'
            Password = 'qqtang_game_dev_pass'
            Database = 'qqtang_game_dev'
            Port = 54331
            ListenAddr = '127.0.0.1:18081'
        }
        DSM = @{
            ListenAddr = '127.0.0.1:18090'
        }
        Room = @{
            Host = '127.0.0.1'
            Port = 9000
        }
    }
}

function Wait-QQTPostgres {
    param(
        [string]$Container,
        [string]$User,
        [string]$Database,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        docker exec $Container pg_isready -U $User -d $Database *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "Postgres is not ready: $Container"
}

function Invoke-QQTPsql {
    param(
        [string]$Container,
        [string]$User,
        [string]$Password,
        [string]$Database,
        [string]$Sql
    )

    $Sql | docker exec -e PGPASSWORD=$Password -i $Container psql -v ON_ERROR_STOP=1 -U $User -d $Database
    if ($LASTEXITCODE -ne 0) {
        throw "psql execution failed in container: $Container"
    }
}

function Resolve-QQTGodotExecutable {
    param(
        [string]$GodotDir,
        [bool]$PreferConsole
    )

    if ([string]::IsNullOrWhiteSpace($GodotDir)) {
        if ($PreferConsole) {
            return 'Godot_console.exe'
        }
        return 'Godot.exe'
    }

    $consolePath = Join-Path $GodotDir 'Godot_console.exe'
    $guiPath = Join-Path $GodotDir 'Godot.exe'

    if ($PreferConsole -and (Test-Path -LiteralPath $consolePath)) {
        return $consolePath
    }
    if ((-not $PreferConsole) -and (Test-Path -LiteralPath $guiPath)) {
        return $guiPath
    }
    if (Test-Path -LiteralPath $consolePath) {
        return $consolePath
    }
    if (Test-Path -LiteralPath $guiPath) {
        return $guiPath
    }

    throw "Godot executable not found under: $GodotDir"
}

function Quote-QQTPS {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Start-QQTServiceWindow {
    param(
        [string]$PowerShellExe,
        [string]$Title,
        [string]$WorkDir,
        [hashtable]$Env,
        [string]$Command,
        [string]$LogPath = ''
    )

    $lines = @()
    $lines += "`$Host.UI.RawUI.WindowTitle = $(Quote-QQTPS $Title)"
    foreach ($key in $Env.Keys) {
        $lines += "`$env:$key = $(Quote-QQTPS ([string]$Env[$key]))"
    }
    $lines += "Set-Location -LiteralPath $(Quote-QQTPS $WorkDir)"
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $lines += "cmd.exe /c `"$Command 2>&1`" | Tee-Object -FilePath $(Quote-QQTPS $LogPath)"
    } else {
        $lines += $Command
    }

    $guid = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "qqtang_svc_$guid.ps1"
    $lines | Set-Content -LiteralPath $tempScript -Encoding UTF8

    return Start-Process -FilePath $PowerShellExe -ArgumentList @(
        '-NoExit',
        '-ExecutionPolicy', 'Bypass',
        '-File', $tempScript
    ) -PassThru
}
