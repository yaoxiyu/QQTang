param(
    [string]$ProjectPath = '',
    [string]$AssetRoot = 'external/assets/maps/elements',
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

Add-Type -AssemblyName System.Drawing

function Convert-GifToPngFrames {
    param(
        [System.IO.FileInfo]$GifFile,
        [bool]$CleanFrames
    )

    $animRoot = Join-Path $GifFile.Directory.FullName 'anim'
    $targetDir = Join-Path $animRoot $GifFile.BaseName
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    if ($CleanFrames) {
        Get-ChildItem -LiteralPath $targetDir -File -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    $gif = $null
    $canvas = $null
    $graphics = $null
    $frameDimension = $null
    try {
        $gif = [System.Drawing.Image]::FromFile($GifFile.FullName)
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
            $framePath = Join-Path $targetDir ("frame_{0:D4}.png" -f $i)
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

$gifFiles = @(Get-ChildItem -LiteralPath $assetRootPath -Recurse -File -Filter '*.gif')
$converted = 0
$failed = 0

foreach ($gif in $gifFiles) {
    try {
        $frameCount = Convert-GifToPngFrames -GifFile $gif -CleanFrames $CleanExistingFrames.IsPresent
        if ($frameCount -gt 0) {
            $converted += 1
        }
    }
    catch {
        $failed += 1
        Write-Warning ("[map-gif] failed: {0} -> {1}" -f $gif.FullName, $_.Exception.Message)
    }
}

Write-Host ("[map-gif] converted={0} failed={1} root={2}" -f $converted, $failed, $assetRootPath)
if ($failed -gt 0) {
    throw "[map-gif] conversion failed for $failed gif files"
}
