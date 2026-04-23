param(
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

$checks = @(
    @{
        Name = 'legacy_match_format_list'
        Pattern = 'const MATCH_FORMAT_IDS'
        Paths = @('app', 'content', 'services', 'tools')
    },
    @{
        Name = 'legacy_required_party_size_helper'
        Pattern = 'requiredPartySizeFromMatchFormat'
        Paths = @('services')
    },
    @{
        Name = 'legacy_default_match_format_fallback'
        Pattern = '"2v2"'
        Paths = @('app', 'content', 'services', 'tools')
        Excludes = @(
            'content_source',
            'content/match_formats',
            'content/maps/resources',
            'tests',
            '**/*_test.go',
            '**/*_test.gd',
            '**/*.cs'
        )
    }
)

foreach ($check in $checks) {
    $paths = @($check.Paths)
    $excludeArgs = @()
    foreach ($exclude in @($check.Excludes)) {
        if ($null -eq $exclude -or [string]::IsNullOrWhiteSpace([string]$exclude)) {
            continue
        }
        $normalizedExclude = $exclude.Replace('\', '/')
        if ($normalizedExclude.Contains('*')) {
            $excludeArgs += @('-g', ('!{0}' -f $normalizedExclude))
            continue
        }
        $excludeArgs += @('-g', ('!{0}/**' -f $normalizedExclude))
    }
    $args = @('-n', '--fixed-strings', $check.Pattern) + $paths + @('-S') + $excludeArgs
    $result = & rg @args 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result | Out-String))) {
        Write-Host ("[phase29-sanity] FAIL {0}" -f $check.Name)
        Write-Host ($result | Out-String)
        exit 1
    }
}

Write-Host '[phase29-sanity] PASS'
