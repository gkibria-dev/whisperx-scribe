param(
    [string]$PythonCommand = "",
    [string]$EnvironmentPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $ProjectRoot "settings.ps1")
$Settings = Get-ProjectSettings -RepositoryRoot $ProjectRoot

if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
    $PythonCommand = $Settings.environment.pythonCommand
}

if ([string]::IsNullOrWhiteSpace($EnvironmentPath)) {
    $EnvironmentPath = $Settings.environment.venvPath
}

$VenvPath = Resolve-ConfiguredPath -Path $EnvironmentPath -RepositoryRoot $ProjectRoot
$PythonExe = Get-VenvPython -EnvironmentPath $VenvPath

Write-Host "Creating Python virtual environment in: $VenvPath" -ForegroundColor Cyan

if (Test-Path -LiteralPath $PythonExe -PathType Leaf) {
    Write-Host "The environment already exists. Nothing to create." -ForegroundColor Yellow
    exit 0
}

$VenvParent = Split-Path -Parent $VenvPath

if (-not [string]::IsNullOrWhiteSpace($VenvParent) -and
    -not (Test-Path -LiteralPath $VenvParent -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $VenvParent | Out-Null
}

& $PythonCommand -m venv $VenvPath
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create the virtual environment at $VenvPath."
}

Write-Host "Virtual environment created." -ForegroundColor Green
Write-Host "Activate it with:" -ForegroundColor Cyan
Write-Host (Join-Path $VenvPath "Scripts\Activate.ps1")
