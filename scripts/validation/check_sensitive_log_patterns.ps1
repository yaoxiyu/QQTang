param(
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

$root = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    (Resolve-Path $RepoRoot).Path
}

$patterns = @(
    'ticket_debug',
    'secret_sha256',
    'expected_sig=',
    'provided_sig='
)

$regex = [string]::Join('|', ($patterns | ForEach-Object { [regex]::Escape($_) }))
$searchRoots = @(
    (Join-Path $root 'app'),
    (Join-Path $root 'network'),
    (Join-Path $root 'services')
)

$rgArgs = @(
    '-n',
    '--no-heading',
    '--color', 'never',
    '-g', '*.go',
    '-g', '*.gd',
    '-g', '!**/*_test.go',
    '-g', '!**/test/**',
    '-g', '!**/tests/**',
    '-g', '!**/docs/**',
    '-g', '!**/generated/**',
    $regex
) + $searchRoots

$hits = & rg @rgArgs
$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }

if ($exitCode -eq 0) {
    Write-Host '[security] sensitive log pattern detected:' -ForegroundColor Red
    Write-Host $hits
    exit 1
}
if ($exitCode -eq 1) {
    Write-Host '[security] no sensitive log patterns detected.' -ForegroundColor Green
    exit 0
}

Write-Error "rg failed with exit code $exitCode"
