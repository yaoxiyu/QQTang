param(
    [string]$ProjectPath = '',
    [string]$AssetRoot = 'external/assets/source/res/object/misc',
    [string]$OutputRoot = 'external/assets/derived/assets/animation/misc',
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

function Get-RelativeDirectoryPath {
    param(
        [string]$RootPath,
        [string]$DirectoryPath
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($RootPath)
    $normalizedDir = [System.IO.Path]::GetFullPath($DirectoryPath)
    if (-not $normalizedRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $normalizedRoot = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
    }
    $rootUri = [System.Uri]::new($normalizedRoot)
    $dirUri = [System.Uri]::new($normalizedDir + [System.IO.Path]::DirectorySeparatorChar)
    $relative = $rootUri.MakeRelativeUri($dirUri).ToString()
    $relative = [System.Uri]::UnescapeDataString($relative).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if ($relative.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $relative = $relative.Substring(0, $relative.Length - 1)
    }
    if ([string]::IsNullOrWhiteSpace($relative)) {
        return '.'
    }
    return $relative
}

function Convert-GifToPngFrames {
    param(
        [System.IO.FileInfo]$GifFile,
        [string]$SourceRootPath,
        [string]$TargetRootPath,
        [bool]$CleanFrames
    )

    $relativeDir = Get-RelativeDirectoryPath -RootPath $SourceRootPath -DirectoryPath $GifFile.Directory.FullName
    $targetBaseDir = $TargetRootPath
    if (-not [string]::IsNullOrWhiteSpace($relativeDir) -and $relativeDir -ne '.') {
        $targetBaseDir = Join-Path $TargetRootPath $relativeDir
    }
    $targetDir = Join-Path $targetBaseDir $GifFile.BaseName
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
        $frameCount = Convert-GifToPngFrames `
            -GifFile $gif `
            -SourceRootPath $assetRootPath `
            -TargetRootPath $resolvedOutputRoot `
            -CleanFrames $CleanExistingFrames.IsPresent
        if ($frameCount -gt 0) {
            $converted += 1
        }
    }
    catch {
        $failed += 1
        Write-Warning ("[misc-gif] failed: {0} -> {1}" -f $gif.FullName, $_.Exception.Message)
    }
}

Write-Host ("[misc-gif] converted={0} failed={1} source={2} output={3}" -f $converted, $failed, $assetRootPath, $resolvedOutputRoot)
if ($failed -gt 0) {
    throw "[misc-gif] conversion failed for $failed gif files"
}
