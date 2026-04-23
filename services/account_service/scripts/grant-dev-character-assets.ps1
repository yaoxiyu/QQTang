param(
    [Parameter(Mandatory = $true)]
    [string]$AccountID,

    [Parameter(Mandatory = $true)]
    [string]$ProfileID,

    [string]$Dsn = $env:ACCOUNT_POSTGRES_DSN,

    [string]$PsqlExe = "psql",

    [string]$DockerContainer = "",

    [string]$DbUser = "",

    [string]$DbPassword = "",

    [string]$DbName = "",

    [string]$SourceType = "dev_grant",

    [string]$DefaultCharacterID = "",

    [switch]$GrantCharacterSkins = $true
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Dsn)) {
    if ([string]::IsNullOrWhiteSpace($DockerContainer)) {
        throw "ACCOUNT_POSTGRES_DSN is empty. Pass -Dsn/set ACCOUNT_POSTGRES_DSN, or use DockerContainer + DbUser + DbPassword + DbName."
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$characterDir = Join-Path $repoRoot "content\characters\data\character"
$characterSkinDir = Join-Path $repoRoot "content\character_skins\data\skins"

if (-not (Test-Path -LiteralPath $characterDir)) {
    throw "character dir not found: $characterDir"
}

function Get-AssetIdsFromTresDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirPath
    )

    $result = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath $DirPath -File -Filter *.tres | ForEach-Object {
        $result.Add([System.IO.Path]::GetFileNameWithoutExtension($_.Name))
    }
    return $result | Sort-Object -Unique
}

$characterIds = @(Get-AssetIdsFromTresDir -DirPath $characterDir)
if ($characterIds.Count -eq 0) {
    throw "no character assets found under $characterDir"
}

$characterSkinIds = @()
if ($GrantCharacterSkins) {
    if (-not (Test-Path -LiteralPath $characterSkinDir)) {
        throw "character skin dir not found: $characterSkinDir"
    }
    $characterSkinIds = @(Get-AssetIdsFromTresDir -DirPath $characterSkinDir)
}

if ([string]::IsNullOrWhiteSpace($DefaultCharacterID)) {
    $DefaultCharacterID = $characterIds[0]
}

if ($characterIds -notcontains $DefaultCharacterID) {
    throw "DefaultCharacterID '$DefaultCharacterID' is not present in generated character assets."
}

function Convert-ToSqlArrayLiteral {
    param(
        [string[]]$Values
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return "ARRAY[]::text[]"
    }

    $escaped = $Values | ForEach-Object {
        "'" + ($_.Replace("'", "''")) + "'"
    }
    return "ARRAY[" + ($escaped -join ", ") + "]"
}

$escapedAccountID = $AccountID.Replace("'", "''")
$escapedProfileID = $ProfileID.Replace("'", "''")
$escapedSourceType = $SourceType.Replace("'", "''")
$escapedDefaultCharacterID = $DefaultCharacterID.Replace("'", "''")
$characterSqlArray = Convert-ToSqlArrayLiteral -Values $characterIds
$characterSkinSqlArray = Convert-ToSqlArrayLiteral -Values $characterSkinIds

$sqlTemplate = @'
\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM player_profiles
        WHERE account_id = '{0}'
          AND profile_id = '{1}'
    ) THEN
        RAISE EXCEPTION 'profile not found for account_id=% profile_id=%', '{0}', '{1}';
    END IF;
END
$$;

WITH granted_characters AS (
    INSERT INTO player_owned_assets (
        account_id,
        profile_id,
        asset_type,
        asset_id,
        state,
        acquired_at,
        source_type
    )
    SELECT
        '{0}',
        '{1}',
        'character',
        asset_id,
        'owned',
        NOW(),
        '{2}'
    FROM unnest({4}) AS asset_id
    ON CONFLICT (profile_id, asset_type, asset_id)
    DO UPDATE SET
        account_id = EXCLUDED.account_id,
        state = 'owned',
        source_type = EXCLUDED.source_type
    RETURNING 1
),
granted_character_skins AS (
    INSERT INTO player_owned_assets (
        account_id,
        profile_id,
        asset_type,
        asset_id,
        state,
        acquired_at,
        source_type
    )
    SELECT
        '{0}',
        '{1}',
        'character_skin',
        asset_id,
        'owned',
        NOW(),
        '{2}'
    FROM unnest({5}) AS asset_id
    ON CONFLICT (profile_id, asset_type, asset_id)
    DO UPDATE SET
        account_id = EXCLUDED.account_id,
        state = 'owned',
        source_type = EXCLUDED.source_type
    RETURNING 1
),
grant_counts AS (
    SELECT
        (SELECT COUNT(*) FROM granted_characters) AS character_count,
        (SELECT COUNT(*) FROM granted_character_skins) AS character_skin_count
)
UPDATE player_profiles
SET
    default_character_id = CASE
        WHEN default_character_id IS NULL OR btrim(default_character_id) = '' THEN '{3}'
        ELSE default_character_id
    END,
    owned_asset_revision = owned_asset_revision + (
        SELECT character_count + character_skin_count
        FROM grant_counts
    ),
    updated_at = NOW()
WHERE account_id = '{0}'
  AND profile_id = '{1}';

COMMIT;

SELECT
    '{0}' AS account_id,
    '{1}' AS profile_id,
    '{3}' AS default_character_id,
    (SELECT COUNT(*) FROM player_owned_assets WHERE profile_id = '{1}' AND asset_type = 'character' AND state = 'owned') AS owned_character_count,
    (SELECT COUNT(*) FROM player_owned_assets WHERE profile_id = '{1}' AND asset_type = 'character_skin' AND state = 'owned') AS owned_character_skin_count;
'@

$sql = $sqlTemplate -f $escapedAccountID, $escapedProfileID, $escapedSourceType, $escapedDefaultCharacterID, $characterSqlArray, $characterSkinSqlArray

$sqlFile = Join-Path ([System.IO.Path]::GetTempPath()) ("qqtang_grant_dev_character_assets_{0}.sql" -f ([System.Guid]::NewGuid().ToString("N")))
Set-Content -LiteralPath $sqlFile -Value $sql -Encoding UTF8

try {
    Write-Host ("[grant-dev-character-assets] repo_root={0}" -f $repoRoot)
    Write-Host ("[grant-dev-character-assets] account_id={0} profile_id={1}" -f $AccountID, $ProfileID)
    Write-Host ("[grant-dev-character-assets] characters={0} character_skins={1}" -f $characterIds.Count, $characterSkinIds.Count)
    if (-not [string]::IsNullOrWhiteSpace($DockerContainer)) {
        if ([string]::IsNullOrWhiteSpace($DbUser) -or [string]::IsNullOrWhiteSpace($DbPassword) -or [string]::IsNullOrWhiteSpace($DbName)) {
            throw "Docker execution requires -DbUser, -DbPassword, and -DbName."
        }
        Get-Content -LiteralPath $sqlFile -Raw | docker exec -e PGPASSWORD=$DbPassword -i $DockerContainer psql -v ON_ERROR_STOP=1 -U $DbUser -d $DbName
        if ($LASTEXITCODE -ne 0) {
            throw "docker psql exited with code $LASTEXITCODE"
        }
    } else {
        & $PsqlExe $Dsn -f $sqlFile
        if ($LASTEXITCODE -ne 0) {
            throw "psql exited with code $LASTEXITCODE"
        }
    }
} finally {
    Remove-Item -LiteralPath $sqlFile -Force -ErrorAction SilentlyContinue
}
