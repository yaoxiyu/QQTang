# Shared path utilities for PowerShell toolchain scripts.
# Source this file in your script: . "$PSScriptRoot/path_common.ps1"

function Get-RepoRoot {
    param([string]$StartPath = $PSScriptRoot)
    $dir = Resolve-Path $StartPath
    while ($dir) {
        if (Test-Path (Join-Path $dir 'project.godot')) {
            return $dir
        }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    throw "Cannot find repository root (no project.godot found)"
}

function Assert-FileExists {
    param([string]$Path, [string]$Hint)
    if (-not (Test-Path $Path)) {
        $msg = "Required file missing: $Path"
        if ($Hint) { $msg += "`n  Hint: $Hint" }
        throw $msg
    }
}
