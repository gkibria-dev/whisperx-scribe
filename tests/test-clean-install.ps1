<#
.SYNOPSIS
    Automatically validates the complete WhisperX environment setup in an
    isolated temporary copy of the repository.

.DESCRIPTION
    This test does NOT use the existing project's .venv.

    It:
      1. Creates a temporary clean copy of the repository.
      2. Runs all four Phase 1 setup scripts in order.
      3. Verifies the resulting .venv.
      4. Removes the temporary copy unless -KeepTemp is specified.

    This is intended to prove that a freshly cloned repository can build its
    own environment without relying on packages installed manually elsewhere.

    NOTE:
      - Python and FFmpeg must already exist on PATH.
      - Internet access is required because Phase 1 installs Python packages.
      - Hugging Face account/token setup is not part of these four setup scripts.
        It is only required later for speaker diarization.

.PARAMETER PythonCommand
    Python command to use when creating the temporary environment.
    Default: python

.PARAMETER KeepTemp
    Keep the temporary test copy after the test finishes.

.PARAMETER UpgradePip
    Pass -UpgradePip to the WhisperX installation script.

.EXAMPLE
    .\tests\test-clean-install.ps1

.EXAMPLE
    .\tests\test-clean-install.ps1 -UpgradePip -KeepTemp
#>

[CmdletBinding()]
param(
    [string]$PythonCommand = "python",
    [switch]$KeepTemp,
    [switch]$UpgradePip
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$SetupDirectory = Join-Path $RepositoryRoot "01-Environment-Setup"

$requiredFiles = @(
    "requirements.txt",
    "01-Environment-Setup\01-check-prerequisites.ps1",
    "01-Environment-Setup\02-create-environment.ps1",
    "01-Environment-Setup\03-install-whisperx.ps1",
    "01-Environment-Setup\04-verify-installation.ps1"
)

Write-Host "=== WhisperX clean-install test ===" -ForegroundColor Cyan
Write-Host "Repository: $RepositoryRoot"

# -----------------------------------------------------------------------------
# 1. Validate repository structure
# -----------------------------------------------------------------------------
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required project file not found: $relativePath"
    }
}

Write-Host "Repository structure check passed." -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Validate host prerequisites
# -----------------------------------------------------------------------------
$python = Get-Command $PythonCommand -ErrorAction SilentlyContinue
if (-not $python) {
    throw "Python command '$PythonCommand' was not found on PATH."
}

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    throw "FFmpeg was not found on PATH."
}

Write-Host "Python: $(& $PythonCommand --version 2>&1)"
Write-Host "FFmpeg: $(ffmpeg -version 2>&1 | Select-Object -First 1)"

# -----------------------------------------------------------------------------
# 3. Create an isolated temporary repository copy
# -----------------------------------------------------------------------------
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("WhisperX-clean-install-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

Write-Host "Temporary test directory: $testRoot"

try {
    # robocopy is used because it handles repository trees reliably on Windows.
    # Exit codes 0-7 indicate success/non-fatal differences.
    $null = robocopy $RepositoryRoot $testRoot /E /XD ".git" ".venv" "env" "test" /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) {
        throw "Failed to copy repository to temporary test directory. Robocopy exit code: $LASTEXITCODE"
    }

    # -------------------------------------------------------------------------
    # 4. Run Phase 1 exactly as a new clone would
    # -------------------------------------------------------------------------
    $scripts = @(
        "01-check-prerequisites.ps1",
        "02-create-environment.ps1",
        "03-install-whisperx.ps1",
        "04-verify-installation.ps1"
    )

    foreach ($scriptName in $scripts) {
        $scriptPath = Join-Path $testRoot "01-Environment-Setup\$scriptName"

        Write-Host ""
        Write-Host "--- Running $scriptName ---" -ForegroundColor Yellow

        $arguments = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $scriptPath
        )

        if ($scriptName -eq "02-create-environment.ps1") {
            $arguments += @("-PythonCommand", $PythonCommand)
        }

        if ($scriptName -eq "03-install-whisperx.ps1" -and $UpgradePip) {
            $arguments += "-UpgradePip"
        }

        & powershell @arguments

        if ($LASTEXITCODE -ne 0) {
            throw "$scriptName failed with exit code $LASTEXITCODE."
        }
    }

    # -------------------------------------------------------------------------
    # 5. Independent final assertions
    # -------------------------------------------------------------------------
    $venvPython = Join-Path $testRoot ".venv\Scripts\python.exe"

    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
        throw "Clean-install test failed: .venv Python was not created."
    }

    Write-Host ""
    Write-Host "--- Independent environment assertions ---" -ForegroundColor Yellow

    & $venvPython -c "import torch, torchcodec, whisperx; from whisperx.diarize import DiarizationPipeline; print('All required imports OK'); print('PyTorch:', torch.__version__); print('WhisperX:', whisperx.__file__)"

    if ($LASTEXITCODE -ne 0) {
        throw "Independent Python import verification failed."
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "CLEAN-INSTALL TEST PASSED" -ForegroundColor Green
    Write-Host "A fresh environment was created and verified." -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "CLEAN-INSTALL TEST FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "Temporary test directory retained for diagnosis: $testRoot" -ForegroundColor Yellow
    throw
}
finally {
    if (-not $KeepTemp -and (Test-Path -LiteralPath $testRoot)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
