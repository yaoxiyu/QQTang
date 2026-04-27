param(
    [switch]$WithGut
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host "==> $Name"
    & $Action
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
Set-Location $repoRoot

Invoke-Step "Generate protobuf code" {
    & (Join-Path $repoRoot "scripts\\proto\\generate_proto.ps1")
}

Invoke-Step "Run room_service go tests" {
    Push-Location (Join-Path $repoRoot "services\\room_service")
    try {
        go test ./...
    }
    finally {
        Pop-Location
    }
}

Invoke-Step "Run game_service go tests" {
    Push-Location (Join-Path $repoRoot "services\\game_service")
    try {
        go test ./...
    }
    finally {
        Pop-Location
    }
}

Invoke-Step "Run ds_manager_service go tests" {
    Push-Location (Join-Path $repoRoot "services\\ds_manager_service")
    try {
        go test ./...
    }
    finally {
        Pop-Location
    }
}

Invoke-Step "Run C# room client tests" {
    dotnet test (Join-Path $repoRoot "tests\\csharp\\QQTang.RoomClient.Tests\\QQTang.RoomClient.Tests.csproj") -v minimal
}

if ($WithGut) {
    Invoke-Step "Run GUT suite (room related directories)" {
        & (Join-Path $repoRoot "tests\\scripts\\run_gut_suite.ps1")
    }
}
else {
    Write-Host "==> Skip GUT suite (pass -WithGut to enable)"
}

Write-Host "Room validation completed."
