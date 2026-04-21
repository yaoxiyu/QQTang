Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-FailAndExit {
    param(
        [string]$Message,
        [int]$Code = 1
    )
    Write-Error $Message
    exit $Code
}

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Resolve-Path (Join-Path $scriptDir "..\\..")
    Set-Location $repoRoot

    $bufCommand = Get-Command buf -ErrorAction SilentlyContinue
    $bufExecutable = if ($bufCommand) { $bufCommand.Source } else { $null }
    if (-not $bufExecutable) {
        $bufCandidate = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\\WinGet\\Packages") -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "bufbuild.buf_*" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($bufCandidate) {
            $candidateExe = Join-Path $bufCandidate.FullName "buf\\bin\\buf.exe"
            if (Test-Path -LiteralPath $candidateExe) {
                $bufExecutable = $candidateExe
            }
        }
    }
    if (-not $bufExecutable) {
        Write-FailAndExit "buf not found in PATH or WinGet package directory. Install buf and retry." 2
    }

    $generatedRoots = @(
        "services/room_service/internal/gen",
        "services/game_service/internal/gen"
    )

    $generatedTargets = @(
        "services/room_service/internal/gen/qqt/room/v1",
        "services/room_service/internal/gen/qqt/internal/game/v1",
        "services/game_service/internal/gen/qqt/room/v1",
        "services/game_service/internal/gen/qqt/internal/game/v1",
        "network/client_net/generated"
    )

    $generatedReadme = @(
        '# Generated Code',
        '',
        'This directory contains generated code.',
        '',
        '- Do not edit files here manually.',
        '- Source of truth: `proto/`.',
        '- Update path: run `buf generate` through repository scripts.'
    )

    foreach ($dir in $generatedRoots) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath (Join-Path $dir "README.md") -Value $generatedReadme -Encoding UTF8
    }

    foreach ($dir in $generatedTargets) {
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    & $bufExecutable generate
    if ($LASTEXITCODE -ne 0) {
        Write-FailAndExit "buf generate failed with exit code $LASTEXITCODE." $LASTEXITCODE
    }

    Write-Host "Proto generation completed successfully."
    exit 0
}
catch {
    Write-FailAndExit $_.Exception.Message 1
}
