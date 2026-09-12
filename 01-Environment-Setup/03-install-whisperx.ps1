param(
    [switch]$UpgradePip,
    [string]$EnvironmentPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

. (Join-Path $ProjectRoot "settings.ps1")
$Settings = Get-ProjectSettings -RepositoryRoot $ProjectRoot

if ([string]::IsNullOrWhiteSpace($EnvironmentPath)) {
    $EnvironmentPath = $Settings.environment.venvPath
}

$VenvPath = Resolve-ConfiguredPath -Path $EnvironmentPath -RepositoryRoot $ProjectRoot
$Python = Get-VenvPython -EnvironmentPath $VenvPath

if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw "Virtual environment not found at $VenvPath. Run 02-create-environment.ps1 first."
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
