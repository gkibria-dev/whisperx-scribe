# WhisperX Transcription - Environment Setup
# One-time setup for a fresh clone on Windows.
#
# Usage from the repository root:
#   .\01-Environment-Setup\setup.ps1
#
# Optional:
#   .\01-Environment-Setup\setup.ps1 -HFToken "hf_..."
#
# The script:
#   1. Locates Python
#   2. Checks/installs FFmpeg when winget is available
#   3. Creates .venv in the repository root
#   4. Installs requirements.txt
#   5. Configures the Hugging Face token when needed
#   6. Verifies WhisperX and its diarization API

[CmdletBinding()]
param(
    [string]$HFToken = "",
    [string]$PythonCommand = "python",
    [switch]$SkipFfmpegInstall
)

$ErrorActionPreference = "Stop"

# Resolve repository root from this script:
# <repo>\01-Environment-Setup\setup.ps1
$RepoRoot = Split-Path -Parent $PSScriptRoot
$VenvPath = Join-Path $RepoRoot ".venv"
$PythonExe = Join-Path $VenvPath "Scripts\python.exe"
$RequirementsFile = Join-Path $RepoRoot "requirements.txt"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " WhisperX Transcription - Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot"
Write-Host ""

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $PythonExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed with exit code $LASTEXITCODE."
    }
}

# ------------------------------------------------------------
# 1. Python
# ------------------------------------------------------------
Write-Host "[1/6] Checking Python..." -ForegroundColor Yellow

try {
    $pythonVersion = & $PythonCommand --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed."
    }
    Write-Host "      $pythonVersion"
}
catch {
    throw @"
Python was not found.

Install Python 3.10+ and make sure "python" is available in PATH,
then run this setup script again.
"@
}

# ------------------------------------------------------------
# 2. FFmpeg
# ------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Checking FFmpeg..." -ForegroundColor Yellow

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue

if ($ffmpeg) {
    $ffmpegVersion = & ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "      $ffmpegVersion"
}
elseif ($SkipFfmpegInstall) {
    throw "FFmpeg is required but was not found. Install FFmpeg and rerun setup."
}
else {
    Write-Host "      FFmpeg not found." -ForegroundColor DarkYellow

    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if ($winget) {
        Write-Host "      Attempting automatic FFmpeg installation with winget..."
        & winget install --id Gyan.FFmpeg.Shared --exact --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Automatic FFmpeg installation failed. Install FFmpeg manually and rerun setup."
        }

        # Refresh PATH for the current PowerShell process.
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")

        $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue

        if (-not $ffmpeg) {
            throw "FFmpeg was installed but is not available in PATH yet. Close/reopen PowerShell and rerun setup."
        }

        Write-Host "      FFmpeg is available."
    }
    else {
        throw @"
FFmpeg was not found and winget is not available.

Install FFmpeg and add it to PATH, then run this setup script again.
"@
    }
}

# ------------------------------------------------------------
# 3. Virtual environment
# ------------------------------------------------------------
Write-Host ""
Write-Host "[3/6] Creating Python virtual environment..." -ForegroundColor Yellow

if (Test-Path $PythonExe) {
    Write-Host "      Existing .venv found; reusing it."
}
else {
    if (Test-Path $VenvPath) {
        Write-Host "      Existing incomplete .venv found; recreating it." -ForegroundColor DarkYellow
        Remove-Item $VenvPath -Recurse -Force
    }

    & $PythonCommand -m venv $VenvPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create the Python virtual environment."
    }

    if (-not (Test-Path $PythonExe)) {
        throw "Virtual environment creation completed but Python was not found at $PythonExe."
    }

    Write-Host "      Created: $VenvPath"
}

# ------------------------------------------------------------
# 4. Install dependencies
# ------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Installing Python dependencies..." -ForegroundColor Yellow

if (-not (Test-Path $RequirementsFile)) {
    throw "requirements.txt was not found at $RequirementsFile."
}

Invoke-Python @("-m", "pip", "install", "--upgrade", "pip")
Invoke-Python @("-m", "pip", "install", "-r", $RequirementsFile)

Write-Host "      Dependencies installed."

# ------------------------------------------------------------
# 5. Hugging Face token
# ------------------------------------------------------------
Write-Host ""
Write-Host "[5/6] Checking Hugging Face authentication..." -ForegroundColor Yellow

$ExistingToken = [Environment]::GetEnvironmentVariable("HF_TOKEN", "User")

if ([string]::IsNullOrWhiteSpace($HFToken)) {
    $HFToken = $env:HF_TOKEN
}

if ([string]::IsNullOrWhiteSpace($HFToken)) {
    $HFToken = $ExistingToken
}

if ([string]::IsNullOrWhiteSpace($HFToken)) {
    Write-Host ""
    Write-Host "WhisperX speaker diarization requires a Hugging Face access token." -ForegroundColor Cyan
    Write-Host "Create one at https://huggingface.co/settings/tokens"
    Write-Host ""
    Write-Host "Enter the token below. Your input will not be displayed."
    $secureToken = Read-Host "Hugging Face token" -AsSecureString

    if ($secureToken.Length -eq 0) {
        throw "No Hugging Face token was supplied."
    }

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)

    try {
        $HFToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

if ([string]::IsNullOrWhiteSpace($HFToken)) {
    throw "Hugging Face token is empty."
}

# Persist for future PowerShell sessions.
[Environment]::SetEnvironmentVariable("HF_TOKEN", $HFToken, "User")
$env:HF_TOKEN = $HFToken

Write-Host "      HF_TOKEN configured for the current user."

# ------------------------------------------------------------
# 6. Verify installation
# ------------------------------------------------------------
Write-Host ""
Write-Host "[6/6] Verifying WhisperX..." -ForegroundColor Yellow

$whisperxVersion = & $PythonExe -c "import importlib.metadata as m; print(m.version('whisperx'))"
if ($LASTEXITCODE -ne 0) {
    throw "WhisperX is not installed correctly."
}

Write-Host "      WhisperX version: $whisperxVersion"

& $PythonExe -c "import whisperx; assert hasattr(whisperx, 'DiarizationPipeline'); print('DiarizationPipeline: OK')"
if ($LASTEXITCODE -ne 0) {
    throw "WhisperX installed, but DiarizationPipeline is unavailable."
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Environment setup completed successfully" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Virtual environment:"
Write-Host "  $VenvPath"
Write-Host ""
Write-Host "Next step:"
Write-Host '  .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"'
Write-Host ""
Write-Host "You do NOT need to activate .venv manually."
Write-Host ""
