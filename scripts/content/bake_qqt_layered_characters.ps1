param(
    [string]$ProjectPath = '',
    [string]$PartsCsv = 'content_source\qqt_object_manifest\parts.csv',
    [string]$AssembliesCsv = 'content_source\csv\characters\qqt_character_assemblies.csv',
    [string]$LayerRulesCsv = 'content_source\csv\characters\qqt_character_layer_rules.csv',
    [string]$TeamPaletteCsv = 'content_source\csv\team_colors\team_palettes.csv',
    [string]$OutputRoot = 'assets\animation\characters\qqt_layered',
    [string]$TeamVariantOutputRoot = 'assets\animation\characters\qqt_layered_team_variants',
    [string]$OverlayOutputRoot = 'assets\animation\overlays\team_color',
    [string]$AssetPackRoot = '',
    [switch]$AllowExternalOutput,
    [string]$BakeManifestPath = '',
    [ValidateSet('normal', 'm', 'merged')]
    [string]$VariantMode = 'merged',
    [int]$Limit = 0,
    [switch]$NoClean
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

function Join-ProjectPath {
    param([string]$RelativePath)
    return Join-Path $projectRoot ($RelativePath -replace '/', '\')
}

function Resolve-AssetPackPath {
    param([string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($AssetPackRoot)) {
        return Resolve-ProjectPath $RelativePath
    }
    return Join-Path $AssetPackRoot ($RelativePath -replace '/', '\')
}

function Get-FileSha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-RelativeOutputPath {
    param([string]$Path)
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if (-not [string]::IsNullOrWhiteSpace($AssetPackRoot)) {
        $resolvedAssetRoot = (Resolve-Path -LiteralPath $AssetPackRoot).Path.TrimEnd('\')
        if ($resolvedPath.StartsWith($resolvedAssetRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $resolvedPath.Substring($resolvedAssetRoot.Length + 1).Replace('\', '/')
        }
    }
    return $resolvedPath.Replace($projectRoot.Path + '\', '').Replace('\', '/')
}

Add-Type -AssemblyName System.Drawing

$partsPath = Resolve-ProjectPath $PartsCsv
$assembliesPath = Resolve-ProjectPath $AssembliesCsv
$layerRulesPath = Resolve-ProjectPath $LayerRulesCsv
$teamPalettePath = Resolve-ProjectPath $TeamPaletteCsv
if (-not [string]::IsNullOrWhiteSpace($AssetPackRoot)) {
    if (-not (Test-Path -LiteralPath $AssetPackRoot)) {
        New-Item -ItemType Directory -Path $AssetPackRoot -Force | Out-Null
    }
    $AssetPackRoot = (Resolve-Path -LiteralPath $AssetPackRoot).Path
    $OutputRoot = 'derived\assets\animation\characters\qqt_layered'
    $TeamVariantOutputRoot = 'derived\assets\animation\characters\qqt_layered_team_variants'
    $OverlayOutputRoot = 'derived\assets\animation\overlays\team_color'
    if ([string]::IsNullOrWhiteSpace($BakeManifestPath)) {
        $BakeManifestPath = Join-Path $AssetPackRoot 'manifests\qqt_layered_bake_manifest.json'
    }
}
$outputRootPath = Resolve-AssetPackPath $OutputRoot
$teamVariantOutputRootPath = Resolve-AssetPackPath $TeamVariantOutputRoot
$overlayOutputRootPath = Resolve-AssetPackPath $OverlayOutputRoot

if (-not $NoClean) {
    foreach ($pathToClean in @($outputRootPath, $teamVariantOutputRootPath, $overlayOutputRootPath)) {
        if (-not (Test-Path -LiteralPath $pathToClean)) {
            continue
        }
        $resolvedOutputRoot = (Resolve-Path -LiteralPath $pathToClean).Path
        $allowedRoot = (Join-Path $projectRoot 'assets\animation')
        $allowedExternalRoot = if ([string]::IsNullOrWhiteSpace($AssetPackRoot)) { '' } else { (Join-Path $AssetPackRoot 'derived\assets\animation') }
        $isProjectOutput = $resolvedOutputRoot.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)
        $isAllowedExternalOutput = (
            -not [string]::IsNullOrWhiteSpace($allowedExternalRoot) -and
            $AllowExternalOutput -and
            $resolvedOutputRoot.StartsWith($allowedExternalRoot, [System.StringComparison]::OrdinalIgnoreCase)
        )
        if (-not $isProjectOutput -and -not $isAllowedExternalOutput) {
            throw "refuse to clean output outside approved asset roots: $resolvedOutputRoot"
        }
        Remove-Item -LiteralPath $resolvedOutputRoot -Recurse -Force
    }
}
New-Item -ItemType Directory -Path $outputRootPath -Force | Out-Null
New-Item -ItemType Directory -Path $teamVariantOutputRootPath -Force | Out-Null
New-Item -ItemType Directory -Path $overlayOutputRootPath -Force | Out-Null

$parts = @(Import-Csv -LiteralPath $partsPath)
$teamColors = @(
    Import-Csv -LiteralPath $teamPalettePath |
        Where-Object { $_.palette_id -eq 'team_palette_default_8' } |
        Sort-Object { [int]$_.team_id }
)
$layerRuleRows = @(
    Import-Csv -LiteralPath $layerRulesPath |
        Where-Object { $_.enabled -eq 'True' } |
        Sort-Object @{ Expression = { if ($_.direction -eq '*') { 0 } else { 1 } } }, part, direction
)
$assemblies = @(
    Import-Csv -LiteralPath $assembliesPath |
        Where-Object { $_.bake_enabled -eq 'True' } |
        Sort-Object character_id
)
if ($Limit -gt 0) {
    $assemblies = @($assemblies | Select-Object -First $Limit)
}

$partIndex = @{}
foreach ($part in $parts) {
    $key = "{0}|{1}|{2}|{3}|{4}" -f $part.part, $part.source_id, $part.action, $part.project_direction, $part.variant
    if (-not $partIndex.ContainsKey($key)) {
        $partIndex[$key] = New-Object System.Collections.Generic.List[object]
    }
    $partIndex[$key].Add($part) | Out-Null
}

$sourceCache = @{}

function Get-AssemblyPartId {
    param(
        [object]$Assembly,
        [string]$Part
    )

    $propertyName = "{0}_id" -f $Part
    $property = $Assembly.PSObject.Properties[$propertyName]
    if ($null -eq $property) {
        return ''
    }
    return [string]$property.Value
}

function Get-AssemblyCharacterType {
    param([object]$Assembly)
    $property = $Assembly.PSObject.Properties['character_type']
    if ($null -eq $property) {
        return 0
    }
    $characterType = 0
    [void][int]::TryParse([string]$property.Value, [ref]$characterType)
    return $characterType
}

function Get-LayerSpecs {
    param(
        [object]$Assembly,
        [string]$Direction,
        [string[]]$Variants
    )

    $rulesByPart = @{}
    foreach ($rule in $layerRuleRows) {
        $part = [string]$rule.part
        $variant = [string]$rule.variant
        $key = "{0}|{1}" -f $part, $variant
        if (-not $rulesByPart.ContainsKey($key)) {
            $rulesByPart[$key] = New-Object System.Collections.Generic.List[object]
        }
        $rulesByPart[$key].Add($rule) | Out-Null
    }

    $effectiveRules = New-Object System.Collections.Generic.List[object]
    foreach ($key in @($rulesByPart.Keys)) {
        $rules = @($rulesByPart[[string]$key].ToArray())
        $exact = @($rules | Where-Object { $_.direction -eq $Direction } | Select-Object -First 1)
        if ($exact.Count -gt 0) {
            $effectiveRules.Add($exact[0]) | Out-Null
            continue
        }
        $default = @($rules | Where-Object { $_.direction -eq '*' } | Select-Object -First 1)
        if ($default.Count -gt 0) {
            $effectiveRules.Add($default[0]) | Out-Null
        }
    }

    @(
        $effectiveRules |
            Where-Object { $Variants -contains [string]$_.variant } |
            ForEach-Object {
                $part = [string]$_.part
                $id = Get-AssemblyPartId $Assembly $part
                $layerOrder = [int]$_.layer_order
                if ($part -eq 'leg' -and $id -eq '1') {
                    $layerOrder = if ([string]$_.variant -eq 'm') { -999 } else { -1000 }
                }
                [PSCustomObject]@{
                    part = $part
                    id = $id
                    variant = [string]$_.variant
                    layer_order = $layerOrder
                    direction_rule = $_.direction
                }
            } |
            Sort-Object @{ Expression = { [int]$_.layer_order } }, part
    )
}

function Get-PartRecord {
    param(
        [string]$Part,
        [string]$SourceId,
        [string]$Action,
        [string]$Direction,
        [string]$Variant = '',
        [bool]$AllowStandFallback = $true,
        [bool]$AllowDefaultLegMask = $false
    )
    if ([string]::IsNullOrWhiteSpace($SourceId)) {
        return $null
    }
    if ($Variant -eq 'm' -and $Part -eq 'leg' -and $SourceId -eq '1' -and -not $AllowDefaultLegMask) {
        return $null
    }

    $candidateKeys = New-Object System.Collections.Generic.List[string]
    $candidateKeys.Add(("{0}|{1}|{2}|{3}|{4}" -f $Part, $SourceId, $Action, $Direction, $Variant)) | Out-Null
    $candidateKeys.Add(("{0}|{1}|{2}||{3}" -f $Part, $SourceId, $Action, $Variant)) | Out-Null
    if ($AllowStandFallback) {
        $candidateKeys.Add(("{0}|{1}|stand|{2}|{3}" -f $Part, $SourceId, $Direction, $Variant)) | Out-Null
        $candidateKeys.Add(("{0}|{1}|stand||{2}" -f $Part, $SourceId, $Variant)) | Out-Null
    }

    foreach ($key in $candidateKeys) {
        if ($partIndex.ContainsKey($key)) {
            return @($partIndex[$key] | Sort-Object relative_path)[0]
        }
    }
    return $null
}

function Get-Frames {
    param([object]$Record)
    if ($null -eq $Record) {
        return @()
    }
    $path = Join-ProjectPath $Record.source_path
    $sourcePathText = [string]$Record.source_path
    if ($sourcePathText.StartsWith('res://')) {
        $sourcePathText = $sourcePathText.Substring('res://'.Length)
    }
    if (-not [string]::IsNullOrWhiteSpace($AssetPackRoot) -and $sourcePathText -like 'res/object/*') {
        $path = Join-Path $AssetPackRoot ("source\{0}" -f ($sourcePathText -replace '/', '\'))
    }
    if ($sourceCache.ContainsKey($path)) {
        return $sourceCache[$path]
    }

    $image = $null
    $frames = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
    try {
        $image = [System.Drawing.Image]::FromFile($path)
        $dimension = [System.Drawing.Imaging.FrameDimension]::new($image.FrameDimensionsList[0])
        $frameCount = $image.GetFrameCount($dimension)
        for ($i = 0; $i -lt $frameCount; $i++) {
            [void]$image.SelectActiveFrame($dimension, $i)
            $bitmap = New-Object System.Drawing.Bitmap($image.Width, $image.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.DrawImage($image, 0, 0, $image.Width, $image.Height)
            $graphics.Dispose()
            $frames.Add($bitmap) | Out-Null
        }
    }
    finally {
        if ($null -ne $image) {
            $image.Dispose()
        }
    }

    $sourceCache[$path] = @($frames.ToArray())
    return $sourceCache[$path]
}

function Save-Strip {
    param(
        [object[]]$Frames,
        [string]$Path
    )
    $frameArray = @($Frames)
    $frameCount = [int]$frameArray.Count
    if ($frameCount -eq 0) {
        return
    }

    $width = [int]$frameArray[0].Width
    $height = [int]$frameArray[0].Height
    $strip = New-Object System.Drawing.Bitmap(($width * $frameCount), $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($strip)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    for ($i = 0; $i -lt $frameCount; $i++) {
        $graphics.DrawImage($frameArray[$i], $i * $width, 0, $width, $height)
    }
    $graphics.Dispose()

    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $strip.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $strip.Dispose()
}

function Has-PartAction {
    param(
        [string]$Part,
        [string]$SourceId,
        [string]$Action
    )
    if ([string]::IsNullOrWhiteSpace($SourceId)) {
        return $false
    }

    foreach ($variant in @('', 'm')) {
        foreach ($direction in @('', 'right', 'up', 'left', 'down')) {
            $key = "{0}|{1}|{2}|{3}|{4}" -f $Part, $SourceId, $Action, $direction, $variant
            if ($partIndex.ContainsKey($key)) {
                return $true
            }
        }
    }
    return $false
}

function Add-TransparentEffectPixels {
    param(
        [System.Drawing.Bitmap]$Canvas,
        [System.Drawing.Bitmap]$NormalFrame,
        [System.Drawing.Bitmap]$MaskFrame,
        [int]$MinY = 0,
        [int]$MaxY = -1,
        [switch]$BlueOnly
    )

    $copyWidth = [Math]::Min($Canvas.Width, $NormalFrame.Width)
    $copyHeight = [Math]::Min($Canvas.Height, $NormalFrame.Height)
    if (-not $BlueOnly) {
        $copyWidth = [Math]::Min($copyWidth, $MaskFrame.Width)
        $copyHeight = [Math]::Min($copyHeight, $MaskFrame.Height)
    }

    for ($y = 0; $y -lt $copyHeight; $y++) {
        if ($y -lt $MinY) {
            continue
        }
        if ($MaxY -ge 0 -and $y -gt $MaxY) {
            continue
        }
        for ($x = 0; $x -lt $copyWidth; $x++) {
            $normalPixel = $NormalFrame.GetPixel($x, $y)
            if ($normalPixel.A -eq 0) {
                continue
            }
            $isBlueEffect = $normalPixel.B -ge 130 -and $normalPixel.G -ge 80 -and $normalPixel.B -gt ($normalPixel.R + 35)
            if ($BlueOnly) {
                if ($isBlueEffect) {
                    $Canvas.SetPixel($x, $y, $normalPixel)
                }
                continue
            }
            $maskPixel = $MaskFrame.GetPixel($x, $y)
            if ($maskPixel.A -eq 0 -or $isBlueEffect) {
                $Canvas.SetPixel($x, $y, $normalPixel)
            }
        }
    }
}

function Convert-HexToDrawingColor {
    param([string]$Hex)
    $text = $Hex.Trim()
    if ($text.StartsWith('#')) {
        $text = $text.Substring(1)
    }
    if ($text.Length -ne 6) {
        throw "invalid hex color: $Hex"
    }
    return [System.Drawing.Color]::FromArgb(
        255,
        [Convert]::ToInt32($text.Substring(0, 2), 16),
        [Convert]::ToInt32($text.Substring(2, 2), 16),
        [Convert]::ToInt32($text.Substring(4, 2), 16)
    )
}

function New-ColorizedMaskFrame {
    param(
        [System.Drawing.Bitmap]$MaskFrame,
        [System.Drawing.Color]$TeamColor
    )

    $result = New-Object System.Drawing.Bitmap($MaskFrame.Width, $MaskFrame.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($y = 0; $y -lt $MaskFrame.Height; $y++) {
        for ($x = 0; $x -lt $MaskFrame.Width; $x++) {
            $pixel = $MaskFrame.GetPixel($x, $y)
            if ($pixel.A -eq 0) {
                continue
            }
            $luma = (($pixel.R * 0.299) + ($pixel.G * 0.587) + ($pixel.B * 0.114)) / 255.0
            $detail = [Math]::Pow([Math]::Max(0.0, [Math]::Min(1.0, $luma)), 1.08)
            $brightness = [Math]::Min(1.12, 0.50 + ($detail * 0.62))
            $result.SetPixel(
                $x,
                $y,
                [System.Drawing.Color]::FromArgb(
                    $pixel.A,
                    [Math]::Min(255, [int]($TeamColor.R * $brightness)),
                    [Math]::Min(255, [int]($TeamColor.G * $brightness)),
                    [Math]::Min(255, [int]($TeamColor.B * $brightness))
                )
            )
        }
    }
    return $result
}

function Compose-Animation {
    param(
        [object]$Assembly,
        [string]$SourceAction,
        [string]$OutputAction,
        [string]$Direction,
        [bool]$Directional,
        [System.Drawing.Color]$TeamColor = [System.Drawing.Color]::Empty
    )

    $characterType = Get-AssemblyCharacterType $Assembly
    $hasPrimaryAction = $false
    if (-not [string]::IsNullOrWhiteSpace($Assembly.cloth_id)) {
        $hasPrimaryAction = Has-PartAction 'cloth' $Assembly.cloth_id $SourceAction
    } elseif (-not [string]::IsNullOrWhiteSpace($Assembly.body_id)) {
        $hasPrimaryAction = Has-PartAction 'body' $Assembly.body_id $SourceAction
    } elseif (-not [string]::IsNullOrWhiteSpace($Assembly.leg_id)) {
        $hasPrimaryAction = Has-PartAction 'leg' $Assembly.leg_id $SourceAction
    }
    if (-not $hasPrimaryAction) {
        return $null
    }

    $variantPasses = switch ($VariantMode) {
        'normal' { @('') }
        'm' { @('m') }
        default { @('', 'm') }
    }
    $layerSpecs = @(Get-LayerSpecs $Assembly $Direction $variantPasses)

    $layers = New-Object System.Collections.Generic.List[object]
    foreach ($spec in $layerSpecs) {
        $record = Get-PartRecord $spec.part $spec.id $SourceAction $Direction $spec.variant $Directional ($characterType -eq 4)
        if ($null -eq $record) {
            continue
        }
        $frames = @(Get-Frames $record)
        if ($frames.Count -eq 0) {
            continue
        }
        $layers.Add([PSCustomObject]@{
            part = $spec.part
            variant = $spec.variant
            layer_order = $spec.layer_order
            record = $record
            frames = $frames
        }) | Out-Null
    }

    if ($layers.Count -eq 0) {
        return $null
    }

    $master = @($layers | Where-Object { $_.part -eq 'cloth' } | Select-Object -First 1)
    if ($master.Count -eq 0) {
        $master = @($layers | Where-Object { $_.part -eq 'body' } | Select-Object -First 1)
    }
    if ($master.Count -eq 0) {
        $master = @($layers | Select-Object -First 1)
    }
    $width = $master[0].frames[0].Width
    $height = $master[0].frames[0].Height
    $frameCount = [int](@($layers | ForEach-Object { $_.frames.Count }) | Measure-Object -Maximum).Maximum

    $outputFrames = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
    for ($frameIndex = 0; $frameIndex -lt $frameCount; $frameIndex++) {
        $canvas = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        $graphics.Clear([System.Drawing.Color]::Transparent)
        foreach ($layer in $layers) {
            $layerFrames = $layer.frames
            $sourceFrame = $layerFrames[$frameIndex % $layerFrames.Count]
            if ($layer.variant -eq 'm' -and -not $TeamColor.IsEmpty) {
                $colorized = New-ColorizedMaskFrame $sourceFrame $TeamColor
                $graphics.DrawImage($colorized, 0, 0, $width, $height)
                $colorized.Dispose()
            } else {
                $graphics.DrawImage($sourceFrame, 0, 0, $width, $height)
            }
        }
        $graphics.Dispose()
        if ($VariantMode -eq 'merged' -and -not $Directional) {
            $normalLayers = @($layers | Where-Object { $_.variant -eq '' })
            foreach ($normalLayer in $normalLayers) {
                $maskLayer = @($layers | Where-Object { $_.variant -eq 'm' -and $_.part -eq $normalLayer.part } | Select-Object -First 1)
                if ($maskLayer.Count -eq 0) {
                    continue
                }
                $normalFrame = $normalLayer.frames[$frameIndex % $normalLayer.frames.Count]
                $maskFrame = $maskLayer[0].frames[$frameIndex % $maskLayer[0].frames.Count]
                Add-TransparentEffectPixels $canvas $normalFrame $maskFrame
            }
            if ($OutputAction -in @('defeat', 'dead')) {
                $tearRecord = Get-PartRecord 'cloth' $Assembly.cloth_id 'faint' '' '' $false
                if ($null -ne $tearRecord) {
                    $tearFrames = @(Get-Frames $tearRecord)
                    if ($tearFrames.Count -gt 0) {
                        $tearFrame = $tearFrames[$frameIndex % $tearFrames.Count]
                        $tearMinY = [int][Math]::Floor($height * 0.25)
                        $tearMaxY = [int][Math]::Floor($height * 0.44)
                        Add-TransparentEffectPixels $canvas $tearFrame $tearFrame $tearMinY $tearMaxY -BlueOnly
                    }
                }
            }
        }
        $outputFrames.Add($canvas) | Out-Null
    }

    return [PSCustomObject]@{
        action = $OutputAction
        direction = $Direction
        frames = @($outputFrames.ToArray())
    }
}

$directions = @('right', 'up', 'left', 'down')
$actionMap = @(
    @{ source = 'stand'; output = 'idle'; directional = $true },
    @{ source = 'walk'; output = 'run'; directional = $true },
    @{ source = 'die'; output = 'dead'; directional = $false },
    @{ source = 'win'; output = 'victory'; directional = $false },
    @{ source = 'lose'; output = 'defeat'; directional = $false },
    @{ source = 'cry'; output = 'cry'; directional = $false },
    @{ source = 'faint'; output = 'stunned'; directional = $false },
    @{ source = 'trigger'; output = 'trigger'; directional = $false },
    @{ source = 'wait'; output = 'wait'; directional = $false },
    @{ source = 'birth'; output = 'spawn'; directional = $false }
)

$itemCharacterActionMap = @(
    @{ source = 'stand'; output = 'idle'; directional = $true },
    @{ source = 'walk'; output = 'run'; directional = $true }
)

$manifestRows = New-Object System.Collections.Generic.List[object]
$teamVariantManifestRows = New-Object System.Collections.Generic.List[object]
$overlayManifestRows = New-Object System.Collections.Generic.List[object]
$bakedCount = 0
$teamVariantBakedCount = 0
$overlayBakedCount = 0

foreach ($assembly in $assemblies) {
    $characterDir = Join-Path $outputRootPath $assembly.character_id
    $characterType = Get-AssemblyCharacterType $assembly
    $effectiveActionMap = if ($characterType -eq 4) { $itemCharacterActionMap } else { $actionMap }
    foreach ($action in $effectiveActionMap) {
        $actionDirections = if ($action.directional) { $directions } else { @('down') }
        foreach ($direction in $actionDirections) {
            $animation = Compose-Animation $assembly $action.source $action.output $direction $action.directional
            if ($null -eq $animation) {
                continue
            }
            $outputFile = Join-Path $characterDir ("{0}_{1}.png" -f $action.output, $direction)
            Save-Strip $animation.frames $outputFile
            $firstFrame = $animation.frames[0]
            $manifestRows.Add([PSCustomObject]@{
                character_id = $assembly.character_id
                assembly_id = $assembly.assembly_id
                variant_mode = $VariantMode
                source_action = $action.source
                output_action = $action.output
                direction = $direction
                output_path = Get-RelativeOutputPath $outputFile
                frame_width = $firstFrame.Width
                frame_height = $firstFrame.Height
                frame_count = $animation.frames.Count
            }) | Out-Null
            foreach ($frame in $animation.frames) {
                $frame.Dispose()
            }
            $bakedCount++

            if ($characterType -in @(1, 2, 3, 5)) {
                foreach ($team in $teamColors) {
                    $teamId = [int]$team.team_id
                    $teamColor = Convert-HexToDrawingColor $team.ui_color_hex
                    $teamAnimation = Compose-Animation $assembly $action.source $action.output $direction $action.directional $teamColor
                    if ($null -eq $teamAnimation) {
                        continue
                    }
                    $teamDir = Join-Path (Join-Path $teamVariantOutputRootPath $assembly.character_id) ("team_{0:D2}" -f $teamId)
                    $teamOutputFile = Join-Path $teamDir ("{0}_{1}.png" -f $action.output, $direction)
                    Save-Strip $teamAnimation.frames $teamOutputFile
                    $teamFirstFrame = $teamAnimation.frames[0]
                    $teamVariantManifestRows.Add([PSCustomObject]@{
                        character_id = $assembly.character_id
                        assembly_id = $assembly.assembly_id
                        team_id = $teamId
                        variant_mode = 'team_color'
                        source_action = $action.source
                        output_action = $action.output
                        direction = $direction
                        output_path = Get-RelativeOutputPath $teamOutputFile
                        frame_width = $teamFirstFrame.Width
                        frame_height = $teamFirstFrame.Height
                        frame_count = $teamAnimation.frames.Count
                    }) | Out-Null
                    foreach ($frame in $teamAnimation.frames) {
                        $frame.Dispose()
                    }
                    $teamVariantBakedCount++
                }
            }
        }
    }
}

$overlayAssembly = [PSCustomObject]@{
    character_id = 'team_marker_leg1'
    assembly_id = 'team_marker_leg1'
    character_type = 4
    body_id = ''
    cloth_id = ''
    leg_id = '1'
    foot_id = ''
    head_id = ''
    hair_id = ''
    face_id = ''
    mouth_id = ''
    npack_id = ''
    cap_id = ''
    fhadorn_id = ''
    thadorn_id = ''
    cladorn_id = ''
}
foreach ($team in $teamColors) {
    $teamId = [int]$team.team_id
    $teamColor = Convert-HexToDrawingColor $team.ui_color_hex
    foreach ($action in $itemCharacterActionMap) {
        foreach ($direction in $directions) {
            $animation = Compose-Animation $overlayAssembly $action.source $action.output $direction $action.directional $teamColor
            if ($null -eq $animation) {
                continue
            }
            $overlayDir = Join-Path (Join-Path $overlayOutputRootPath 'leg1') ("team_{0:D2}" -f $teamId)
            $overlayOutputFile = Join-Path $overlayDir ("{0}_{1}.png" -f $action.output, $direction)
            Save-Strip $animation.frames $overlayOutputFile
            $firstFrame = $animation.frames[0]
            $overlayManifestRows.Add([PSCustomObject]@{
                overlay_id = 'team_marker_leg1'
                team_id = $teamId
                source_action = $action.source
                output_action = $action.output
                direction = $direction
                output_path = Get-RelativeOutputPath $overlayOutputFile
                frame_width = $firstFrame.Width
                frame_height = $firstFrame.Height
                frame_count = $animation.frames.Count
            }) | Out-Null
            foreach ($frame in $animation.frames) {
                $frame.Dispose()
            }
            $overlayBakedCount++
        }
    }
}

$manifestPath = Join-Path $outputRootPath 'qqt_layered_bake_manifest.csv'
New-Item -ItemType Directory -Path $outputRootPath -Force | Out-Null
$manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding utf8
$teamVariantManifestPath = Join-Path $teamVariantOutputRootPath 'qqt_layered_team_variant_bake_manifest.csv'
$teamVariantManifestRows | Export-Csv -LiteralPath $teamVariantManifestPath -NoTypeInformation -Encoding utf8
$overlayManifestPath = Join-Path $overlayOutputRootPath 'team_color_overlay_bake_manifest.csv'
$overlayManifestRows | Export-Csv -LiteralPath $overlayManifestPath -NoTypeInformation -Encoding utf8

if (-not [string]::IsNullOrWhiteSpace($BakeManifestPath)) {
    $bakeManifestDir = Split-Path -Parent $BakeManifestPath
    New-Item -ItemType Directory -Path $bakeManifestDir -Force | Out-Null
    $sourceManifestPath = Resolve-ProjectPath 'content_source\qqt_object_manifest\parts.csv'
    $bakeManifest = [ordered]@{
        schema_version = 1
        bake_id = 'qqt_layered_bake'
        bake_version = '2'
        created_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        toolchain = [ordered]@{
            os = $PSVersionTable.OS
            powershell = $PSVersionTable.PSVersion.ToString()
            image_backend = 'System.Drawing'
        }
        inputs = [ordered]@{
            parts_csv_sha256 = Get-FileSha256 $partsPath
            assemblies_csv_sha256 = Get-FileSha256 $assembliesPath
            layer_rules_csv_sha256 = Get-FileSha256 $layerRulesPath
            team_palettes_csv_sha256 = Get-FileSha256 $teamPalettePath
            bake_script_sha256 = Get-FileSha256 $PSCommandPath
            source_object_manifest_sha256 = Get-FileSha256 $sourceManifestPath
        }
        outputs = [ordered]@{
            qqt_layered_file_count = $bakedCount
            team_variant_file_count = $teamVariantBakedCount
            overlay_file_count = $overlayBakedCount
            pixel_hash = ''
        }
    }
    [System.IO.File]::WriteAllText($BakeManifestPath, ($bakeManifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
}

foreach ($entry in $sourceCache.GetEnumerator()) {
    foreach ($frame in @($entry.Value)) {
        $frame.Dispose()
    }
}

Write-Host ("[qqt-bake] variant={0} assemblies={1} animations={2} team_variants={3} overlays={4} output={5}" -f $VariantMode, $assemblies.Count, $bakedCount, $teamVariantBakedCount, $overlayBakedCount, $outputRootPath)
