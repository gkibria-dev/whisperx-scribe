<#
.SYNOPSIS
    Validates that a clean repository can create and verify a WhisperX environment.

.DESCRIPTION
    Creates an isolated temporary copy of the repository and runs the public
    Phase 1 setup.ps1 entry point.

    The test intentionally does not use the repository's existing .venv.
    This simulates the important "fresh clone -> setup" scenario.

    The setup script is responsible for handling FFmpeg installation/verification,
    so this test does not require FFmpeg to already be on PATH.

.PARAMETER PythonCommand
    Python command available on the host. Default: python.

.PARAMETER KeepTemp
    Keep the temporary test repository for troubleshooting.

.EXAMPLE
    .\tests\test-clean-install.ps1

.EXAMPLE
    .\tests\test-clean-install.ps1 -KeepTemp

.EXAMPLE
    .\tests\test-clean-install.ps1 -PythonCommand py
#>

[CmdletBinding()]
param(
    [string]$PythonCommand = "python",
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$SetupScript = Join-Path $RepositoryRoot "01-Environment-Setup\setup.ps1"

$requiredFiles = @(
    "requirements.txt",
    "01-Environment-Setup\setup.ps1",
    "02-Transcription-Pipeline\run_pipeline.ps1",
    "02-Transcription-Pipeline\scripts\transcribe.py",
    "02-Transcription-Pipeline\scripts\align_and_merge.py",
    "02-Transcription-Pipeline\scripts\diarize.py",
    "02-Transcription-Pipeline\scripts\finalize.py"
)

Write-Host "=== WhisperX clean-install test ===" -ForegroundColor Cyan
Write-Host "Repository: $RepositoryRoot"

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required project file not found: $relativePath"
    }
}

$python = Get-Command $PythonCommand -ErrorAction SilentlyContinue
if (-not $python) {
    throw "Python command '$PythonCommand' was not found on PATH."
}

Write-Host "Python: $(& $PythonCommand --version 2>&1)"

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    ("WhisperX-clean-install-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
Write-Host "Temporary test directory: $testRoot"

try {
    # Exclude generated/local environments and repository metadata.
    $null = robocopy `
        $RepositoryRoot `
        $testRoot `
        /E `
        /XD ".git" ".venv" "env" `
        /NFL /NDL /NJH /NJS /NP

    if ($LASTEXITCODE -gt 7) {
        throw "Failed to copy repository to temporary test directory. Robocopy exit code: $LASTEXITCODE"
    }

    $testSetupScript = Join-Path $testRoot "01-Environment-Setup\setup.ps1"

    Write-Host ""
    Write-Host "--- Running setup.ps1 in isolated repository ---" -ForegroundColor Yellow

    # Use Bypass only for the child test process so a downloaded/cloned script
    # is not blocked by the host's RemoteSigned policy.
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $testSetupScript `
        -PythonCommand $PythonCommand

    if ($LASTEXITCODE -ne 0) {
        throw "setup.ps1 failed with exit code $LASTEXITCODE."
    }

    $venvPython = Join-Path $testRoot ".venv\Scripts\python.exe"

    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
        throw "Clean-install test failed: .venv Python was not created."
    }

    Write-Host ""
    Write-Host "--- Independent environment assertions ---" -ForegroundColor Yellow

    & $venvPython -c "import torch, whisperx; from whisperx.diarize import DiarizationPipeline; print('WhisperX import OK'); print('DiarizationPipeline import OK'); print('PyTorch:', torch.__version__); print('WhisperX:', whisperx.__version__ if hasattr(whisperx, '__version__') else 'installed')"

    if ($LASTEXITCODE -ne 0) {
        throw "Independent Python import verification failed."
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "CLEAN-INSTALL TEST PASSED" -ForegroundColor Green
    Write-Host "Fresh repository environment created and verified." -ForegroundColor Green
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
