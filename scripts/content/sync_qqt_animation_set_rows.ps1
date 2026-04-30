param(
    [string]$ProjectPath = '',
    [string]$CharactersCsv = 'content_source\csv\characters\characters.csv',
    [string]$AnimationSetsCsv = 'content_source\csv\character_animation_sets\character_animation_sets.csv',
    [string]$TeamVariantRoot = 'assets\animation\characters\qqt_layered_team_variants',
    [string]$OverlayRoot = 'assets\animation\overlays\team_color',
    [string]$RuntimeStripManifest = 'content\character_animation_sets\data\runtime_strips\character_animation_strip_sets.json',
    [string]$AssetPackRoot = '',
    [string]$AssetPackId = 'qqt-assets',
    [switch]$ProjectAssetUris,
    [switch]$RegisterGeneratedRows
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}

function Resolve-ProjectPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $projectRoot $Path
}

function Test-ProjectFile {
    param([string]$ResourcePath)
    if ([string]::IsNullOrWhiteSpace($ResourcePath)) {
        return $false
    }
    $relative = $ResourcePath.Trim().Replace('res://', '').Replace('/', '\')
    return Test-Path -LiteralPath (Join-Path $projectRoot $relative)
}

function Resolve-OptionalPath {
    param([string]$ResourcePath)
    if (Test-ProjectFile $ResourcePath) {
        return $ResourcePath
    }
    return ''
}

function New-StripResourcePath {
    param(
        [string]$RelativePath,
        [switch]$Optional
    )
    $normalized = $RelativePath.Replace('\', '/').TrimStart('/')
    if ($ProjectAssetUris) {
        $resourcePath = 'res://' + $normalized
        return Resolve-OptionalPath $resourcePath
    }
    if ($Optional) {
        $projectPath = Join-Path $projectRoot ($normalized -replace '/', '\')
        $assetPath = if ([string]::IsNullOrWhiteSpace($AssetPackRoot)) {
            ''
        } else {
            Join-Path $AssetPackRoot ("derived\{0}" -f ($normalized -replace '/', '\'))
        }
        if (-not (Test-Path -LiteralPath $projectPath) -and ([string]::IsNullOrWhiteSpace($assetPath) -or -not (Test-Path -LiteralPath $assetPath))) {
            return ''
        }
    }
    return "asset://$AssetPackId/derived/$normalized"
}

function ConvertTo-StringValue {
    param($Value)
    if ($null -eq $Value) {
        return ''
    }
    return [string]$Value
}

function ConvertTo-IntValue {
    param($Value, [int]$DefaultValue = 0)
    $parsed = $DefaultValue
    if ([int]::TryParse((ConvertTo-StringValue $Value), [ref]$parsed)) {
        return $parsed
    }
    return $DefaultValue
}

function ConvertTo-FloatValue {
    param($Value, [double]$DefaultValue = 0.0)
    $parsed = $DefaultValue
    if ([double]::TryParse((ConvertTo-StringValue $Value), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        return $parsed
    }
    return $DefaultValue
}

function ConvertTo-BoolValue {
    param($Value, [bool]$DefaultValue = $false)
    $text = (ConvertTo-StringValue $Value).Trim().ToLowerInvariant()
    if ($text -in @('true', '1', 'yes')) {
        return $true
    }
    if ($text -in @('false', '0', 'no')) {
        return $false
    }
    return $DefaultValue
}

function New-RuntimeStripManifestEntry {
    param($Row)
    return [ordered]@{
        animation_set_id = ConvertTo-StringValue $Row.animation_set_id
        display_name = ConvertTo-StringValue $Row.display_name
        strips = [ordered]@{
            run_down = ConvertTo-StringValue $Row.down_strip_path
            run_left = ConvertTo-StringValue $Row.left_strip_path
            run_right = ConvertTo-StringValue $Row.right_strip_path
            run_up = ConvertTo-StringValue $Row.up_strip_path
            idle_down = ConvertTo-StringValue $Row.idle_down_strip_path
            idle_left = ConvertTo-StringValue $Row.idle_left_strip_path
            idle_right = ConvertTo-StringValue $Row.idle_right_strip_path
            idle_up = ConvertTo-StringValue $Row.idle_up_strip_path
            wait_down = ConvertTo-StringValue $Row.wait_down_strip_path
            trigger_down = ConvertTo-StringValue $Row.trigger_down_strip_path
            dead_down = ConvertTo-StringValue $Row.dead_down_strip_path
            defeat_down = ConvertTo-StringValue $Row.defeat_down_strip_path
            win_down = ConvertTo-StringValue $Row.win_down_strip_path
        }
        frame_width = ConvertTo-IntValue $Row.frame_width 100
        frame_height = ConvertTo-IntValue $Row.frame_height 100
        frames_per_direction = ConvertTo-IntValue $Row.frames_per_direction 6
        run_fps = ConvertTo-FloatValue $Row.run_fps 8.0
        idle_frame_index = ConvertTo-IntValue $Row.idle_frame_index 0
        pivot_origin = [ordered]@{
            x = ConvertTo-FloatValue $Row.pivot_x 50.0
            y = ConvertTo-FloatValue $Row.pivot_y 100.0
        }
        pivot_adjust = [ordered]@{
            x = ConvertTo-FloatValue $Row.pivot_adjust_x 0.0
            y = ConvertTo-FloatValue $Row.pivot_adjust_y -15.0
        }
        loop_run = ConvertTo-BoolValue $Row.loop_run $true
        loop_idle = ConvertTo-BoolValue $Row.loop_idle $false
        content_hash = ConvertTo-StringValue $Row.content_hash
    }
}

$charactersPath = Resolve-ProjectPath $CharactersCsv
$animationSetsPath = Resolve-ProjectPath $AnimationSetsCsv
$runtimeStripManifestPath = Resolve-ProjectPath $RuntimeStripManifest
$teamVariantRootResource = ($TeamVariantRoot -replace '\\', '/').TrimEnd('/')
$overlayRootResource = ($OverlayRoot -replace '\\', '/').TrimEnd('/')

$rows = @(Import-Csv -LiteralPath $animationSetsPath)
$charactersById = @{}
foreach ($character in (Import-Csv -LiteralPath $charactersPath)) {
    $charactersById[[string]$character.character_id] = $character
}

$baseRows = @(
    $rows |
        Where-Object {
            $_.animation_set_id -notmatch '^char_anim_qqt_.+_team_[0-9]{2}$' -and
            $_.animation_set_id -notmatch '^team_marker_leg1_team_[0-9]{2}$'
        }
)
$generatedRows = New-Object System.Collections.Generic.List[object]

foreach ($baseRow in $baseRows) {
    $animationSetId = [string]$baseRow.animation_set_id
    if ($animationSetId -notmatch '^char_anim_qqt_(.+)$') {
        continue
    }
    $characterId = $Matches[1]
    if (-not $charactersById.ContainsKey($characterId)) {
        continue
    }
    $characterType = 0
    [void][int]::TryParse([string]$charactersById[$characterId].type, [ref]$characterType)
    if ($characterType -notin @(1, 2, 3, 5)) {
        continue
    }

    for ($teamId = 1; $teamId -le 8; $teamId++) {
        $teamRoot = "$teamVariantRootResource/$characterId/team_{0:D2}" -f $teamId
        $generatedRows.Add([PSCustomObject]@{
            animation_set_id = ("{0}_team_{1:D2}" -f $animationSetId, $teamId)
            display_name = ("{0} team_{1:D2}" -f $baseRow.display_name, $teamId)
            down_strip_path = New-StripResourcePath "$teamRoot/run_down.png"
            left_strip_path = New-StripResourcePath "$teamRoot/run_left.png"
            right_strip_path = New-StripResourcePath "$teamRoot/run_right.png"
            up_strip_path = New-StripResourcePath "$teamRoot/run_up.png"
            idle_down_strip_path = New-StripResourcePath "$teamRoot/idle_down.png"
            idle_left_strip_path = New-StripResourcePath "$teamRoot/idle_left.png"
            idle_right_strip_path = New-StripResourcePath "$teamRoot/idle_right.png"
            idle_up_strip_path = New-StripResourcePath "$teamRoot/idle_up.png"
            frame_width = $baseRow.frame_width
            frame_height = $baseRow.frame_height
            frames_per_direction = $baseRow.frames_per_direction
            run_fps = $baseRow.run_fps
            idle_frame_index = $baseRow.idle_frame_index
            pivot_x = $baseRow.pivot_x
            pivot_y = $baseRow.pivot_y
            pivot_adjust_x = $baseRow.pivot_adjust_x
            pivot_adjust_y = $baseRow.pivot_adjust_y
            loop_run = $baseRow.loop_run
            loop_idle = $baseRow.loop_idle
            wait_down_strip_path = New-StripResourcePath "$teamRoot/wait_down.png" -Optional
            trigger_down_strip_path = New-StripResourcePath "$teamRoot/trigger_down.png" -Optional
            dead_down_strip_path = New-StripResourcePath "$teamRoot/dead_down.png" -Optional
            defeat_down_strip_path = New-StripResourcePath "$teamRoot/defeat_down.png" -Optional
            win_down_strip_path = New-StripResourcePath "$teamRoot/victory_down.png" -Optional
            content_hash = ("qqt_{0}_team_{1:D2}_layered_bake_v1" -f $characterId, $teamId)
        }) | Out-Null
    }
}

for ($teamId = 1; $teamId -le 8; $teamId++) {
    $teamRoot = "$overlayRootResource/leg1/team_{0:D2}" -f $teamId
    $generatedRows.Add([PSCustomObject]@{
        animation_set_id = ("team_marker_leg1_team_{0:D2}" -f $teamId)
        display_name = ("Team Marker Leg1 team_{0:D2}" -f $teamId)
        down_strip_path = New-StripResourcePath "$teamRoot/run_down.png"
        left_strip_path = New-StripResourcePath "$teamRoot/run_left.png"
        right_strip_path = New-StripResourcePath "$teamRoot/run_right.png"
        up_strip_path = New-StripResourcePath "$teamRoot/run_up.png"
        idle_down_strip_path = New-StripResourcePath "$teamRoot/idle_down.png"
        idle_left_strip_path = New-StripResourcePath "$teamRoot/idle_left.png"
        idle_right_strip_path = New-StripResourcePath "$teamRoot/idle_right.png"
        idle_up_strip_path = New-StripResourcePath "$teamRoot/idle_up.png"
        frame_width = 100
        frame_height = 100
        frames_per_direction = 6
        run_fps = 8
        idle_frame_index = 0
        pivot_x = 50
        pivot_y = 100
        pivot_adjust_x = 0
        pivot_adjust_y = -15
        loop_run = 'true'
        loop_idle = 'false'
        wait_down_strip_path = ''
        trigger_down_strip_path = ''
        dead_down_strip_path = ''
        defeat_down_strip_path = ''
        win_down_strip_path = ''
        content_hash = ("team_marker_leg1_team_{0:D2}_bake_v1" -f $teamId)
    }) | Out-Null
}

$headers = @(
    'animation_set_id',
    'display_name',
    'down_strip_path',
    'left_strip_path',
    'right_strip_path',
    'up_strip_path',
    'idle_down_strip_path',
    'idle_left_strip_path',
    'idle_right_strip_path',
    'idle_up_strip_path',
    'frame_width',
    'frame_height',
    'frames_per_direction',
    'run_fps',
    'idle_frame_index',
    'pivot_x',
    'pivot_y',
    'pivot_adjust_x',
    'pivot_adjust_y',
    'loop_run',
    'loop_idle',
    'wait_down_strip_path',
    'trigger_down_strip_path',
    'dead_down_strip_path',
    'defeat_down_strip_path',
    'win_down_strip_path',
    'content_hash'
)

$allRows = if ($RegisterGeneratedRows) { @($baseRows) + @($generatedRows.ToArray()) } else { @($baseRows) }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add(($headers -join ',')) | Out-Null
foreach ($row in $allRows) {
    $values = foreach ($header in $headers) {
        [string]$row.$header
    }
    $lines.Add(($values -join ',')) | Out-Null
}
[System.IO.File]::WriteAllLines($animationSetsPath, $lines, [System.Text.UTF8Encoding]::new($false))

$manifestEntries = foreach ($generatedRow in $generatedRows.ToArray()) {
    New-RuntimeStripManifestEntry $generatedRow
}
$mergedManifestEntriesById = [ordered]@{}
if (Test-Path -LiteralPath $runtimeStripManifestPath) {
    $existingManifest = Get-Content -Raw -LiteralPath $runtimeStripManifestPath | ConvertFrom-Json
    foreach ($entry in @($existingManifest.entries)) {
        $entryId = ConvertTo-StringValue $entry.animation_set_id
        if (-not [string]::IsNullOrWhiteSpace($entryId)) {
            $mergedManifestEntriesById[$entryId] = $entry
        }
    }
}
foreach ($entry in @($manifestEntries)) {
    $entryId = ConvertTo-StringValue $entry.animation_set_id
    if (-not [string]::IsNullOrWhiteSpace($entryId)) {
        $mergedManifestEntriesById[$entryId] = $entry
    }
}
$mergedManifestEntries = foreach ($entryId in @($mergedManifestEntriesById.Keys | Sort-Object)) {
    $mergedManifestEntriesById[$entryId]
}
$manifest = [ordered]@{
    schema_version = 1
    generated_by = 'scripts/content/sync_qqt_animation_set_rows.ps1'
    entries = @($mergedManifestEntries)
}
$runtimeStripManifestDir = Split-Path -Parent $runtimeStripManifestPath
if (-not (Test-Path -LiteralPath $runtimeStripManifestDir)) {
    New-Item -ItemType Directory -Force -Path $runtimeStripManifestDir | Out-Null
}
$manifestJson = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($runtimeStripManifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

Write-Host ("[qqt-animation-sets] base={0} generated={1} registered={2} output={3} manifest={4}" -f $baseRows.Count, $generatedRows.Count, $(if ($RegisterGeneratedRows) { $generatedRows.Count } else { 0 }), $animationSetsPath, $runtimeStripManifestPath)
