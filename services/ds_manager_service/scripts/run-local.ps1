param(
    [string]$EnvFile = '',
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDev = Join-Path $scriptDir 'run-dev.ps1'

& $runDev -Profile $Profile -EnvFile $EnvFile
