param(
    [string]$ProjectPath = '',
    [string]$AssetRoot = 'external/assets/source/res/object/item',
    [string]$OutputRoot = 'external/assets/derived/assets/animation/items',
    [switch]$CleanExistingFrames
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $projectRoot = Resolve-Path -LiteralPath $ProjectPath
}
$projectRoot = $projectRoot.Path

$resolvedAssetRoot = if ([System.IO.Path]::IsPathRooted($AssetRoot)) {
    Resolve-Path -LiteralPath $AssetRoot
} else {
    Resolve-Path -LiteralPath (Join-Path $projectRoot $AssetRoot)
}
$assetRootPath = $resolvedAssetRoot.Path

$resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot
} else {
    Join-Path $projectRoot $OutputRoot
}
New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null

Add-Type -AssemblyName System.Drawing

function Convert-GifToPngFrames {
    param(
        [string]$GifPath,
        [string]$TargetDir,
        [bool]$CleanFrames
    )

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

    if ($CleanFrames) {
        Get-ChildItem -LiteralPath $TargetDir -File -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    $gif = $null
    $canvas = $null
    $graphics = $null
    try {
        $gif = [System.Drawing.Image]::FromFile($GifPath)
        $frameDimension = [System.Drawing.Imaging.FrameDimension]::new($gif.FrameDimensionsList[0])
        $frameCount = $gif.GetFrameCount($frameDimension)
        if ($frameCount -le 0) {
            return 0
        }
        $canvas = New-Object System.Drawing.Bitmap($gif.Width, $gif.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        $graphics.Clear([System.Drawing.Color]::Transparent)

        for ($i = 0; $i -lt $frameCount; $i++) {
            [void]$gif.SelectActiveFrame($frameDimension, $i)
            $graphics.Clear([System.Drawing.Color]::Transparent)
            [void]$graphics.DrawImage($gif, 0, 0, $gif.Width, $gif.Height)
            $framePath = Join-Path $TargetDir ("frame_{0:D4}.png" -f $i)
            $canvas.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        return $frameCount
    }
    finally {
        if ($null -ne $graphics) { $graphics.Dispose() }
        if ($null -ne $canvas) { $canvas.Dispose() }
        if ($null -ne $gif) { $gif.Dispose() }
    }
}

function Copy-PngAsSingleFrame {
    param(
        [string]$PngPath,
        [string]$TargetDir
    )

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    $framePath = Join-Path $TargetDir 'frame_0000.png'
    Copy-Item -LiteralPath $PngPath -Destination $framePath -Force
    return 1
}

$allFiles = @(Get-ChildItem -LiteralPath $assetRootPath -File)
$items = @{}

foreach ($f in $allFiles) {
    $itemId = $null
    $animType = $null

    if ($f.Name -match '^[iI]tem(\d+)_(stand|trigger)') {
        $itemId = [int]$matches[1]
        $animType = $matches[2].ToLowerInvariant()
    } else {
        continue
    }

    $key = "$itemId"
    if (-not $items.ContainsKey($key)) {
        $items[$key] = @{ id = $itemId; stand = $null; trigger = $null }
    }

    if ($animType -eq 'stand') {
        $items[$key].stand = $f
    } elseif ($animType -eq 'trigger') {
        $items[$key].trigger = $f
    }
}

$converted = 0
$failed = 0
$framesTotal = 0

foreach ($key in ($items.Keys | Sort-Object { [int]$_ })) {
    $item = $items[$key]
    $itemId = $item.id
    $itemOutputRoot = Join-Path $resolvedOutputRoot $itemId.ToString()

    if ($item.stand -ne $null) {
        $targetDir = Join-Path $itemOutputRoot 'stand'
        $ext = $item.stand.Extension.ToLowerInvariant()
        try {
            if ($ext -eq '.gif') {
                $frameCount = Convert-GifToPngFrames -GifPath $item.stand.FullName -TargetDir $targetDir -CleanFrames:$CleanExistingFrames.IsPresent
            } elseif ($ext -eq '.png') {
                $frameCount = Copy-PngAsSingleFrame -PngPath $item.stand.FullName -TargetDir $targetDir
            } else {
                continue
            }
            if ($frameCount -gt 0) {
                $converted += 1
                $framesTotal += $frameCount
            }
        }
        catch {
            $failed += 1
            Write-Warning ("[item-gif] failed stand: {0} -> {1}" -f $item.stand.FullName, $_.Exception.Message)
        }
    }

    if ($item.trigger -ne $null) {
        $targetDir = Join-Path $itemOutputRoot 'trigger'
        try {
            $frameCount = Convert-GifToPngFrames -GifPath $item.trigger.FullName -TargetDir $targetDir -CleanFrames:$CleanExistingFrames.IsPresent
            if ($frameCount -gt 0) {
                $converted += 1
                $framesTotal += $frameCount
            }
        }
        catch {
            $failed += 1
            Write-Warning ("[item-gif] failed trigger: {0} -> {1}" -f $item.trigger.FullName, $_.Exception.Message)
        }
    }
}

Write-Host ("[item-gif] items={0} converted={1} failed={2} frames={3} output={4}" -f $items.Count, $converted, $failed, $framesTotal, $resolvedOutputRoot)
if ($failed -gt 0) {
    throw "[item-gif] conversion failed for $failed files"
}
