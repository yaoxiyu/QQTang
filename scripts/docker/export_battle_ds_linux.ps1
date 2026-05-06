param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$Preset = 'Linux Dedicated Server',
    [string]$OutputPath = 'build/docker/battle_ds/qqtang_battle_ds.x86_64',
    [string]$PackOutputPath = 'build/docker/battle_ds/qqtang_battle_ds.pck',
    [string]$MainScene = 'res://scenes/network/dedicated_server_scene.tscn',
    [string]$NativeLibSource = 'external/qqt_native/bin/qqt_native.linux.template_release.x86_64.so',
    [string]$NativeLibOutputPath = 'build/docker/battle_ds/qqt_native.linux.template_release.x86_64.so',
    [switch]$SkipNativeLibCopy,
    [switch]$ForceBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$repoRoot = $repoRoot.Path
. (Join-Path $repoRoot 'tools\lib\dev_common.ps1')
$cacheRoot = Join-Path $repoRoot 'build\.docker-cache'
$activity = 'battle-ds-export'
$absoluteOutput = Join-Path $repoRoot $OutputPath
$absolutePackOutput = Join-Path $repoRoot $PackOutputPath
$absoluteNativeSource = Join-Path $repoRoot $NativeLibSource
$absoluteNativeOutput = Join-Path $repoRoot $NativeLibOutputPath
$outputDir = Split-Path -Parent $absoluteOutput
$presetPath = Join-Path $repoRoot 'export_presets.cfg'
$presetTemplatePath = Join-Path $repoRoot 'scripts/docker/export_presets.battle_ds.cfg'
$presetBackupPath = Join-Path $repoRoot 'export_presets.cfg.phase36_backup'
$projectPath = Join-Path $repoRoot 'project.godot'
$projectBackupPath = Join-Path $repoRoot 'project.godot.phase36_battle_ds_backup'
$externalNativeRoot = Join-Path $repoRoot 'external\qqt_native'
$externalNativeGodotIgnore = Join-Path $externalNativeRoot '.gdignore'
$createdPreset = $false
$backedUpPreset = $false
$backedUpProject = $false

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}
if (-not (Test-Path -LiteralPath $presetTemplatePath)) {
    throw "Battle DS export preset template not found: $presetTemplatePath"
}
if (-not (Test-Path -LiteralPath $projectPath)) {
    throw "Godot project file not found: $projectPath"
}
if ((Test-Path -LiteralPath $externalNativeRoot -PathType Container) -and -not (Test-Path -LiteralPath $externalNativeGodotIgnore)) {
    New-Item -ItemType File -Path $externalNativeGodotIgnore -Force | Out-Null
}

Push-Location $repoRoot
try {
    $null = Invoke-QQTIncrementalStep `
        -Root $repoRoot `
        -CacheRoot $cacheRoot `
        -Name 'battle_ds_linux_export' `
        -IncludePaths @(
            'app',
            'content',
            'gameplay',
            'network',
            'presentation',
            'scenes',
            'addons',
            'scripts\docker\export_battle_ds_linux.ps1',
            'scripts\docker\export_presets.battle_ds.cfg',
            'project.godot',
            $NativeLibSource
        ) `
        -ExcludePathParts @(
            '\.godot\',
            '\build\',
            '\logs\',
            '\tests\reports\',
            '\addons\qqt_native\third_party\godot-cpp\bin\',
            '\addons\qqt_native\third_party\godot-cpp\gen\'
        ) `
        -OutputPaths @($OutputPath, $PackOutputPath, $NativeLibOutputPath) `
        -Force:$ForceBuild `
        -Activity $activity `
        -Step 1 `
        -Total 1 `
        -Action {
            if (Test-Path -LiteralPath $presetPath) {
                Copy-Item -LiteralPath $presetPath -Destination $presetBackupPath -Force
                $script:backedUpPreset = $true
            } else {
                Copy-Item -LiteralPath $presetTemplatePath -Destination $presetPath -Force
                $script:createdPreset = $true
            }
            Copy-Item -LiteralPath $projectPath -Destination $projectBackupPath -Force
            $script:backedUpProject = $true
            $projectText = Get-Content -LiteralPath $projectPath -Raw
            $escapedMainScene = $MainScene.Replace('\', '\\').Replace('"', '\"')
            $mainScenePattern = '(?m)^run/main_scene=.*$'
            if (-not [regex]::IsMatch($projectText, $mainScenePattern)) {
                throw "project.godot does not contain application/run/main_scene"
            }
            $updatedProjectText = [regex]::Replace(
                $projectText,
                $mainScenePattern,
                ('run/main_scene="{0}"' -f $escapedMainScene)
            )
            Set-Content -LiteralPath $projectPath -Value $updatedProjectText -Encoding UTF8

            powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1 -GodotExe $GodotExe
            New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
            & cmd /c "`"$GodotExe`" --headless --path `"$repoRoot`" --export-release `"$Preset`" `"$absoluteOutput`""
            if ($LASTEXITCODE -ne 0) {
                throw "Godot Linux dedicated server export failed (exit code: $LASTEXITCODE)"
            }
            if (-not (Test-Path -LiteralPath $absoluteOutput)) {
                throw "Export completed but binary was not created: $absoluteOutput"
            }
            & cmd /c "`"$GodotExe`" --headless --path `"$repoRoot`" --export-pack `"$Preset`" `"$absolutePackOutput`""
            if ($LASTEXITCODE -ne 0) {
                throw "Godot Linux dedicated server pack export failed (exit code: $LASTEXITCODE)"
            }
            if (-not (Test-Path -LiteralPath $absolutePackOutput)) {
                throw "Export completed but pack was not created: $absolutePackOutput"
            }
            if (-not $SkipNativeLibCopy) {
                if (-not (Test-Path -LiteralPath $absoluteNativeSource)) {
                    throw "Native Linux release library not found: $absoluteNativeSource"
                }
                Copy-Item -LiteralPath $absoluteNativeSource -Destination $absoluteNativeOutput -Force
            }
        }
}
finally {
    if ($backedUpProject -and (Test-Path -LiteralPath $projectBackupPath)) {
        Copy-Item -LiteralPath $projectBackupPath -Destination $projectPath -Force
        Remove-Item -LiteralPath $projectBackupPath -Force
    }
    if ($createdPreset -and (Test-Path -LiteralPath $presetPath)) {
        Remove-Item -LiteralPath $presetPath -Force
    }
    if ($backedUpPreset -and (Test-Path -LiteralPath $presetBackupPath)) {
        Copy-Item -LiteralPath $presetBackupPath -Destination $presetPath -Force
        Remove-Item -LiteralPath $presetBackupPath -Force
    }
    Pop-Location
}
Write-QQTProgress -Activity $activity -Completed

Write-Host "[battle-ds-export] created $absoluteOutput"
Write-Host "[battle-ds-export] created $absolutePackOutput"
if (-not $SkipNativeLibCopy) {
    Write-Host "[battle-ds-export] synced $absoluteNativeOutput"
}
