Set-StrictMode -Version Latest

function Resolve-QQTProjectRoot {
    param([string]$ProjectPath)

    if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
        return (Resolve-Path -LiteralPath $ProjectPath).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\.." )).Path
}

function Resolve-QQTRelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $normalizedPath = [System.IO.Path]::GetFullPath($Path)
    $rootWithSeparator = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
    if ($normalizedPath.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedPath.Substring($rootWithSeparator.Length).Replace('\', '/')
    }
    return $normalizedPath.Replace('\', '/')
}

function Get-QQTFileFingerprint {
    param(
        [string]$Root,
        [string[]]$IncludePaths,
        [string[]]$ExcludePathParts = @()
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    foreach ($includePath in $IncludePaths) {
        if ([string]::IsNullOrWhiteSpace($includePath)) {
            continue
        }
        $absolutePath = if ([System.IO.Path]::IsPathRooted($includePath)) {
            $includePath
        } else {
            Join-Path $resolvedRoot $includePath
        }
        if (-not (Test-Path -LiteralPath $absolutePath)) {
            continue
        }
        $item = Get-Item -LiteralPath $absolutePath -Force
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $absolutePath -Recurse -File -Force | ForEach-Object {
                $files.Add($_)
            }
        } else {
            $files.Add($item)
        }
    }

    $records = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in ($files | Sort-Object FullName -Unique)) {
        $normalizedFullName = $file.FullName.Replace('/', '\')
        $excluded = $false
        foreach ($part in $ExcludePathParts) {
            if ([string]::IsNullOrWhiteSpace($part)) {
                continue
            }
            $normalizedPart = $part.Replace('/', '\')
            if ($normalizedFullName.IndexOf($normalizedPart, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $excluded = $true
                break
            }
        }
        if ($excluded) {
            continue
        }

        $relativePath = Resolve-QQTRelativePath -Root $resolvedRoot -Path $file.FullName
        $fileHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $records.Add(('{0}|{1}' -f $relativePath, $fileHash))
    }

    $payload = [string]::Join("`n", $records)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        return [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Test-QQTOutputsExist {
    param(
        [string]$Root,
        [string[]]$Paths
    )

    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $absolutePath = if ([System.IO.Path]::IsPathRooted($path)) {
            $path
        } else {
            Join-Path $Root $path
        }
        if (-not (Test-Path -LiteralPath $absolutePath)) {
            return $false
        }
    }
    return $true
}

function Write-QQTProgress {
    param(
        [string]$Activity,
        [int]$Step,
        [int]$Total,
        [string]$Status,
        [switch]$Completed
    )

    if ([string]::IsNullOrWhiteSpace($Activity)) {
        return
    }
    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
        return
    }
    $safeTotal = [Math]::Max(1, $Total)
    $safeStep = [Math]::Min([Math]::Max(1, $Step), $safeTotal)
    $percent = [int](($safeStep - 1) * 100 / $safeTotal)
    Write-Progress -Activity $Activity -Status ("[{0}/{1}] {2}" -f $safeStep, $safeTotal, $Status) -PercentComplete $percent
}

function Invoke-QQTProgressStep {
    param(
        [string]$Activity,
        [int]$Step,
        [int]$Total,
        [string]$Name,
        [scriptblock]$Action
    )

    Write-QQTProgress -Activity $Activity -Step $Step -Total $Total -Status $Name
    Write-Host ("[{0}] {1}/{2} {3}" -f $Activity, $Step, $Total, $Name)
    $startedAt = Get-Date
    & $Action
    $elapsed = (Get-Date) - $startedAt
    Write-Host ("[{0}] done {1} ({2:n1}s)" -f $Activity, $Name, $elapsed.TotalSeconds)
}

function Invoke-QQTIncrementalStep {
    param(
        [string]$Root,
        [string]$CacheRoot,
        [string]$Name,
        [string[]]$IncludePaths,
        [string[]]$ExcludePathParts = @(),
        [string[]]$OutputPaths = @(),
        [switch]$Force,
        [string]$Activity = '',
        [int]$Step = 1,
        [int]$Total = 1,
        [scriptblock]$Action
    )

    New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
    Write-QQTProgress -Activity $Activity -Step $Step -Total $Total -Status ("fingerprint {0}" -f $Name)
    $fingerprint = Get-QQTFileFingerprint -Root $Root -IncludePaths $IncludePaths -ExcludePathParts $ExcludePathParts
    $stampPath = Join-Path $CacheRoot ("{0}.sha256" -f $Name)
    $previousFingerprint = ''
    if (Test-Path -LiteralPath $stampPath -PathType Leaf) {
        $previousFingerprint = (Get-Content -LiteralPath $stampPath -Raw).Trim()
    }

    if ((-not $Force) -and $previousFingerprint -eq $fingerprint -and (Test-QQTOutputsExist -Root $Root -Paths $OutputPaths)) {
        Write-Host ("[{0}] skip {1} (inputs unchanged)" -f $(if ([string]::IsNullOrWhiteSpace($Activity)) { 'cache' } else { $Activity }), $Name)
        return $false
    }

    Invoke-QQTProgressStep -Activity $Activity -Step $Step -Total $Total -Name $Name -Action $Action
    Set-Content -LiteralPath $stampPath -Value $fingerprint -Encoding ASCII
    return $true
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
            Port = 9100
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
        $repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
        $binaryRoot = Join-Path $repoRoot 'external\godot_binary'
        return Join-Path $binaryRoot 'Godot.exe'
    }

    $guiPath = Join-Path $GodotDir 'Godot.exe'

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
