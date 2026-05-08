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
            'content/character_animation_sets/generated',
            'content/match_formats',
            'content/maps/resources',
            'tests',
            '**/*_test.go',
            '**/*_test.gd',
            '**/*.cs'
        )
    }
)

function Test-IsExcluded {
    param(
        [string]$RelativePath,
        [object[]]$Excludes
    )

    foreach ($exclude in @($Excludes)) {
        if ($null -eq $exclude -or [string]::IsNullOrWhiteSpace([string]$exclude)) {
            continue
        }
        $normalizedExclude = ([string]$exclude).Replace('\', '/')
        if ($normalizedExclude.Contains('*')) {
            if ($RelativePath -like $normalizedExclude) {
                return $true
            }
            continue
        }
        if ($RelativePath -eq $normalizedExclude -or $RelativePath.StartsWith($normalizedExclude + '/')) {
            return $true
        }
    }
    return $false
}

function Find-MatchesWithPowerShell {
    param(
        [string]$RepoRoot,
        [string]$Pattern,
        [object[]]$Paths,
        [object[]]$Excludes
    )

    $matches = @()
    foreach ($path in @($Paths)) {
        $fullPath = Join-Path $RepoRoot $path
        if (-not (Test-Path -LiteralPath $fullPath)) {
            continue
        }
        Get-ChildItem -LiteralPath $fullPath -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
            if (Test-IsExcluded -RelativePath $relativePath -Excludes $Excludes) {
                return
            }
            $hit = Select-String -LiteralPath $_.FullName -SimpleMatch -Pattern $Pattern -ErrorAction SilentlyContinue
            if ($null -ne $hit) {
                foreach ($item in @($hit)) {
                    $matches += ('{0}:{1}:{2}' -f $relativePath, $item.LineNumber, $item.Line.Trim())
                }
            }
        }
    }
    return $matches
}

foreach ($check in $checks) {
    $paths = @($check.Paths)
    $excludes = @()
    if ($check.ContainsKey('Excludes')) {
        $excludes = @($check.Excludes)
    }
    $result = @()
    $rgCommand = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -ne $rgCommand) {
        $excludeArgs = @()
        foreach ($exclude in $excludes) {
            if ($null -eq $exclude -or [string]::IsNullOrWhiteSpace([string]$exclude)) {
                continue
            }
            $normalizedExclude = ([string]$exclude).Replace('\', '/')
            if ($normalizedExclude.Contains('*')) {
                $excludeArgs += @('-g', ('!{0}' -f $normalizedExclude))
                continue
            }
            $excludeArgs += @('-g', ('!{0}/**' -f $normalizedExclude))
        }
        $args = @('-n', '--fixed-strings', $check.Pattern) + $paths + @('-S') + $excludeArgs
        $result = & rg @args 2>$null
        if ($LASTEXITCODE -ne 0) {
            $result = @()
        }
    } else {
        $result = Find-MatchesWithPowerShell -RepoRoot $repoRoot -Pattern $check.Pattern -Paths $paths -Excludes $excludes
    }

    if (-not [string]::IsNullOrWhiteSpace(($result | Out-String))) {
        Write-Host ("[content-sanity] FAIL {0}" -f $check.Name)
        Write-Host ($result | Out-String)
        exit 1
    }
}

Write-Host '[content-sanity] PASS'
