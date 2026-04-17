# serve.ps1 — PowerShell counterpart to serve.sh.
# Usage: .\serve.ps1 [-Port 1313]

param(
    [int]$Port = 1313
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $root '.hugo.pid'

if (-not (Get-Command hugo -ErrorAction SilentlyContinue)) {
    Write-Error @"
serve.ps1: hugo is not installed.
Install it: https://github.com/gohugoio/hugo/releases/tag/v0.160.1
Or on Windows: winget install Hugo.Hugo.Extended
"@
    exit 1
}

$sitePath = Join-Path $root 'site'
if (-not (Test-Path $sitePath)) {
    Write-Error "serve.ps1: no site/ directory found at $root"
    exit 1
}

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        Write-Error "serve.ps1: a server is already running (pid $oldPid). Use .\stop.ps1 first, or pass -Port to run a second one."
        exit 1
    }
    Remove-Item $pidFile -Force
}

Write-Host "serve.ps1: starting hugo server -D --port $Port from $sitePath"
$PID | Out-File -FilePath $pidFile -Encoding ASCII

try {
    Set-Location $sitePath
    & hugo server -D --port $Port --bind 127.0.0.1
}
finally {
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force }
}
