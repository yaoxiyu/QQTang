param(
    [string]$GodotExecutable = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$ProjectPath = '',
    [switch]$ForceBuild
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}
$projectRoot = $projectRoot.Path
. (Join-Path $projectRoot 'tools\lib\dev_common.ps1')

$syntaxPreflightScript = Join-Path $projectRoot 'tests\scripts\check_gdscript_syntax.ps1'
$cacheRoot = Join-Path $projectRoot 'build\.content-pipeline-cache'
$activity = 'content-pipeline'
Invoke-QQTProgressStep -Activity $activity -Step 1 -Total 3 -Name 'gdscript syntax preflight' -Action {
    & $syntaxPreflightScript -GodotExe $GodotExecutable -ProjectPath $projectRoot
}

Push-Location $projectRoot
try {
    $requiredPaths = @(
        'content\maps\resources\map_classic_square.tres',
        'content\maps\resources\map_breakable_center_lane.tres',
        'content\match_formats\data\formats\1v1.tres',
        'content\match_formats\data\formats\2v2.tres',
        'content\match_formats\data\formats\4v4.tres',
        'build\generated\room_manifest\room_manifest.json',
        'build\generated\content_catalog\characters_catalog_index.json',
        'build\generated\content_catalog\bubbles_catalog_index.json',
        'build\generated\content_catalog\maps_catalog_index.json',
        'build\generated\content_catalog\modes_catalog_index.json',
        'build\generated\content_catalog\rulesets_catalog_index.json',
        'build\generated\content_catalog\match_formats_catalog_index.json',
        'build\generated\content_catalog\content_catalog_summary.json',
        'build\generated\content_reports\content_pipeline_report.json'
    )

    Invoke-QQTIncrementalStep `
        -Root $projectRoot `
        -CacheRoot $cacheRoot `
        -Name 'content_pipeline' `
        -IncludePaths @(
            'content_source\csv',
            'tools\content_pipeline',
            'scripts\content\run_content_pipeline.ps1',
            'scripts\content\sync_qqt_animation_set_rows.ps1',
            'content\characters\defs',
            'content\bubbles\defs',
            'content\maps\defs',
            'content\modes\defs',
            'content\rulesets\defs',
            'content\match_formats\defs',
            'external\assets\derived\assets\animation\characters\qqt_layered',
            'external\assets\derived\assets\animation\characters\qqt_layered_team_variants'
        ) `
        -ExcludePathParts @(
            '\.godot\',
            '\build\',
            '\logs\',
            '\tests\reports\'
        ) `
        -OutputPaths $requiredPaths `
        -Force:$ForceBuild `
        -Activity $activity `
        -Step 2 `
        -Total 3 `
        -Action {
            & cmd /c "`"$GodotExecutable`" --headless --path `"$projectRoot`" --script res://tools/content_pipeline/run_content_pipeline_cli.gd"
            if ($LASTEXITCODE -ne 0) {
                throw "content pipeline failed (godot exit code: $LASTEXITCODE)"
            }

            $syncQqtAnimationSetsScript = Join-Path $projectRoot 'scripts\content\sync_qqt_animation_set_rows.ps1'
            if (Test-Path -LiteralPath $syncQqtAnimationSetsScript) {
                & $syncQqtAnimationSetsScript -ProjectPath $projectRoot -AssetPackRoot (Join-Path $projectRoot 'external\assets')
            }
        } | Out-Null

    Write-QQTProgress -Activity $activity -Step 3 -Total 3 -Status 'verify outputs'

    foreach ($relativePath in $requiredPaths) {
        $fullPath = Join-Path $projectRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "missing content pipeline output: $fullPath"
        }
    }

    $reportPath = Join-Path $projectRoot 'build\generated\content_reports\content_pipeline_report.json'
    $reportJson = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($null -eq $reportJson) {
        throw "content pipeline report is invalid json: $reportPath"
    }
    $errorCount = @($reportJson.errors).Count
    Write-Host ("[content] report error_count={0}" -f $errorCount)
    if ($errorCount -gt 0) {
        throw "content pipeline report contains errors: $errorCount"
    }
    Write-QQTProgress -Activity $activity -Completed
}
finally {
    Pop-Location
}

Write-Host "[content] content pipeline generated successfully"
