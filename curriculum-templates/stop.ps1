# stop.ps1 — PowerShell counterpart to stop.sh.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $root '.hugo.pid'

if (-not (Test-Path $pidFile)) {
    Write-Host 'stop.ps1: no running server (no .hugo.pid found).'
    exit 0
}

$targetPid = Get-Content $pidFile -ErrorAction SilentlyContinue
$process = Get-Process -Id $targetPid -ErrorAction SilentlyContinue

if (-not $process) {
    Write-Host "stop.ps1: pidfile pointed to $targetPid but no such process is running. Cleaning up."
    Remove-Item $pidFile -Force
    exit 0
}

Write-Host "stop.ps1: stopping hugo server (pid $targetPid)"
Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
Write-Host 'stop.ps1: stopped.'
