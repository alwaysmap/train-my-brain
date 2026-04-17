# check-hugo.ps1 — PowerShell counterpart to check-hugo.sh.
# Detects Hugo (extended) >= 0.120 on Windows; offers winget / choco / scoop install if missing.
#
# Exit codes:
#   0 — Hugo available at acceptable version
#   1 — Hugo missing or too old and user declined install (or install failed)
#   2 — Hugo missing and no known package manager

$ErrorActionPreference = 'Stop'

$MinVersion = [version]'0.120.0'
$SuggestedVersion = '0.160.1'
$ReleaseUrl = "https://github.com/gohugoio/hugo/releases/tag/v$SuggestedVersion"

function Get-HugoVersion {
    if (Get-Command hugo -ErrorAction SilentlyContinue) {
        $line = (hugo version 2>$null | Select-Object -First 1)
        if ($line -match '^hugo v(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
    }
    return $null
}

function Prompt-YN([string]$Question) {
    $resp = Read-Host "$Question [y/N]"
    return ($resp -match '^[yY]')
}

function Invoke-Install {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host 'Package manager: winget'
        if (Prompt-YN "Install hugo-extended via 'winget install Hugo.Hugo.Extended'?") {
            winget install --id Hugo.Hugo.Extended --silent
            if ($LASTEXITCODE -eq 0) { return 0 }
            Write-Warning 'check-hugo.ps1: winget install failed.'
            return 1
        }
        return 1
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host 'Package manager: choco'
        if (Prompt-YN "Install hugo-extended via 'choco install hugo-extended'?") {
            choco install hugo-extended -y
            if ($LASTEXITCODE -eq 0) { return 0 }
            Write-Warning 'check-hugo.ps1: choco install failed.'
            return 1
        }
        return 1
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host 'Package manager: scoop'
        if (Prompt-YN "Install hugo-extended via 'scoop install hugo-extended'?") {
            scoop install hugo-extended
            if ($LASTEXITCODE -eq 0) { return 0 }
            Write-Warning 'check-hugo.ps1: scoop install failed.'
            return 1
        }
        return 1
    }
    Write-Host 'check-hugo.ps1: no known package manager (winget/choco/scoop). Install Hugo manually:'
    Write-Host "  $ReleaseUrl"
    return 2
}

# ── Main flow ─────────────────────────────────────────────────
$installed = Get-HugoVersion

if (-not $installed) {
    Write-Host 'check-hugo.ps1: Hugo is not installed.'
    Write-Host "TMB needs Hugo >= $MinVersion (extended edition preferred; suggested: $SuggestedVersion)."
    $status = Invoke-Install
    if ($status -eq 0) {
        $installed = Get-HugoVersion
        if (-not $installed) {
            Write-Warning 'check-hugo.ps1: install seemed to succeed but hugo is still not on PATH.'
            exit 1
        }
        Write-Host "check-hugo.ps1: hugo $installed installed."
        exit 0
    }
    exit $status
}

if ($installed -ge $MinVersion) {
    Write-Host "check-hugo.ps1: hugo $installed detected (>= $MinVersion)."
    exit 0
}

Write-Host "check-hugo.ps1: hugo $installed is older than the required $MinVersion."
if (Prompt-YN 'Attempt an upgrade via the system package manager?') {
    $status = Invoke-Install
    if ($status -eq 0) {
        $installed = Get-HugoVersion
        if ($installed -and $installed -ge $MinVersion) {
            Write-Host "check-hugo.ps1: hugo $installed installed."
            exit 0
        }
        Write-Warning "check-hugo.ps1: upgrade attempted but version is still $installed."
        exit 1
    }
    exit $status
}
Write-Host "check-hugo.ps1: upgrade declined. See $ReleaseUrl for manual install."
exit 1
