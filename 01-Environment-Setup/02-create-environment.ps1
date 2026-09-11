param(
    [string]$PythonCommand = "python"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Creating Python virtual environment in: $ProjectRoot\.venv" -ForegroundColor Cyan

if (Test-Path ".venv") {
    Write-Host ".venv already exists. Nothing to create." -ForegroundColor Yellow
    exit 0
}

& $PythonCommand -m venv .venv
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create the virtual environment."
}

Write-Host "Virtual environment created." -ForegroundColor Green
Write-Host "Activate it with:" -ForegroundColor Cyan
Write-Host ".\.venv\Scripts\Activate.ps1"
