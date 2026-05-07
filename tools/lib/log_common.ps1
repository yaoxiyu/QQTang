# Shared logging utilities for PowerShell toolchain scripts.

$Global:ScriptLogIndent = 0

function Write-Step {
    param([string]$Message)
    $indent = '  ' * $Global:ScriptLogIndent
    Write-Host "${indent}[+] $Message"
}

function Write-StepDetail {
    param([string]$Message)
    $indent = '  ' * $Global:ScriptLogIndent
    Write-Host "${indent}    $Message"
}

function Push-Step {
    $Global:ScriptLogIndent++
}

function Pop-Step {
    if ($Global:ScriptLogIndent -gt 0) {
        $Global:ScriptLogIndent--
    }
}
