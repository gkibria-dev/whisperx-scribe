param(
    [switch]$UpgradePip
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$Python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) {
    throw "Virtual environment not found. Run 02-create-environment.ps1 first."
}

Write-Host "Installing WhisperX environment..." -ForegroundColor Cyan

if ($UpgradePip) {
    & $Python -m pip install --upgrade pip
}

# Explicit CPU PyTorch wheels provide a predictable Windows CPU baseline.
& $Python -m pip install --upgrade `
    torch==2.8.0 `
    torchaudio==2.8.0 `
    torchvision==0.23.0 `
    --index-url https://download.pytorch.org/whl/cpu
if ($LASTEXITCODE -ne 0) {
    throw "PyTorch CPU installation failed."
}

& $Python -m pip install --upgrade -r (Join-Path $ProjectRoot "requirements.txt")
if ($LASTEXITCODE -ne 0) {
    throw "WhisperX installation failed."
}

Write-Host "WhisperX installation complete." -ForegroundColor Green
Write-Host "Next: .\01-Environment-Setup\04-verify-installation.ps1"
