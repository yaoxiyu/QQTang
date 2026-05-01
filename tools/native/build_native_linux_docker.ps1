param(
    [string]$Target = "template_release",
    [string]$Arch = "x86_64",
    [string]$Image = "qqtang/native-linux-builder:ubuntu-24.04",
    [switch]$ForceBuild
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path (Join-Path $scriptDir "..\..")
$rootPath = $rootDir.Path
. (Join-Path $rootPath 'tools\lib\dev_common.ps1')
$cacheRoot = Join-Path $rootPath 'build\.native-cache'
$activity = 'native-linux'

function Test-QQTDockerImageExists {
    param([string]$Tag)
    docker image inspect $Tag *> $null
    return $LASTEXITCODE -eq 0
}

$builderFingerprint = Get-QQTFileFingerprint -Root $rootPath -IncludePaths @('tools\native\Dockerfile.linux-build')
$builderStampPath = Join-Path $cacheRoot ("builder_{0}.sha256" -f ($Image -replace '[^A-Za-z0-9_.-]', '_'))
$previousBuilderFingerprint = ''
if (Test-Path -LiteralPath $builderStampPath -PathType Leaf) {
    $previousBuilderFingerprint = (Get-Content -LiteralPath $builderStampPath -Raw).Trim()
}
if ((-not $ForceBuild) -and $previousBuilderFingerprint -eq $builderFingerprint -and (Test-QQTDockerImageExists -Tag $Image)) {
    Write-Host "[qqt_native] skip Linux native builder image (inputs unchanged): $Image"
} else {
    Invoke-QQTProgressStep -Activity $activity -Step 1 -Total 2 -Name "builder image $Image" -Action {
        docker build -f (Join-Path $rootPath "tools\native\Dockerfile.linux-build") -t $Image $rootPath
        if ($LASTEXITCODE -ne 0) {
            throw "native Linux builder image build failed (docker exit code: $LASTEXITCODE)"
        }
    }
    New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
    Set-Content -LiteralPath $builderStampPath -Value $builderFingerprint -Encoding ASCII
}

$nativeOutput = Join-Path $rootPath ("external\qqt_native\bin\qqt_native.linux.{0}.{1}.so" -f $Target, $Arch)
Invoke-QQTIncrementalStep `
    -Root $rootPath `
    -CacheRoot $cacheRoot `
    -Name ("linux_artifact_{0}_{1}" -f $Target, $Arch) `
    -IncludePaths @(
        'addons\qqt_native\SConstruct',
        'addons\qqt_native\src',
        'addons\qqt_native\qqt_native.gdextension',
        'addons\qqt_native\third_party\godot-cpp\binding_generator.py',
        'addons\qqt_native\third_party\godot-cpp\SConstruct',
        'addons\qqt_native\third_party\godot-cpp\godot-headers',
        'addons\qqt_native\third_party\godot-cpp\include',
        'addons\qqt_native\third_party\godot-cpp\src',
        'tools\native\build_native_linux.sh',
        'tools\native\build_native_linux_docker.ps1'
    ) `
    -ExcludePathParts @(
        '\addons\qqt_native\third_party\godot-cpp\bin\',
        '\addons\qqt_native\third_party\godot-cpp\gen\',
        '\addons\qqt_native\bin\',
        '\external\qqt_native\bin\'
    ) `
    -OutputPaths @($nativeOutput) `
    -Force:$ForceBuild `
    -Activity $activity `
    -Step 2 `
    -Total 2 `
    -Action {
        $mountPath = $rootPath -replace "\\", "/"
        Write-Host "[qqt_native] building Linux native artifact in Ubuntu 24.04 container target=$Target arch=$Arch"
        docker run --rm `
            -v "${mountPath}:/workspace" `
            -w /workspace `
            $Image `
            $Target `
            $Arch
        if ($LASTEXITCODE -ne 0) {
            throw "native Linux artifact build failed (docker exit code: $LASTEXITCODE)"
        }
    } | Out-Null
Write-QQTProgress -Activity $activity -Completed
