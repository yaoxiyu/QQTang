param(
    [string]$Target = "template_release",
    [string]$Arch = "x86_64",
    [string]$Image = "qqtang/native-linux-builder:ubuntu-24.04"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path (Join-Path $scriptDir "..\..")

Write-Host "[qqt_native] building Linux native builder image: $Image"
docker build -f (Join-Path $rootDir "tools\native\Dockerfile.linux-build") -t $Image $rootDir

$mountPath = $rootDir.Path -replace "\\", "/"
Write-Host "[qqt_native] building Linux native artifact in Ubuntu 24.04 container target=$Target arch=$Arch"
docker run --rm `
    -v "${mountPath}:/workspace" `
    -w /workspace `
    $Image `
    $Target `
    $Arch
