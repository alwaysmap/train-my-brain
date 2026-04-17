# build.ps1 — PowerShell counterpart to build.sh.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command hugo -ErrorAction SilentlyContinue)) {
    Write-Error 'build.ps1: hugo is not installed.'
    exit 1
}

$sitePath = Join-Path $root 'site'
if (-not (Test-Path $sitePath)) {
    Write-Error "build.ps1: no site/ directory found at $root"
    exit 1
}

Set-Location $sitePath
Write-Host 'build.ps1: running hugo --minify'
& hugo --minify

Write-Host 'build.ps1: site/public/ is current.'
