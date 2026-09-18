<#
.SYNOPSIS
    Validates that a clean repository can create and verify a WhisperX environment.

.DESCRIPTION
    Creates an isolated temporary copy of the repository and runs the public
    Phase 1 setup.ps1 entry point.

    The test builds its own throwaway environment under test.environmentPath and
    never touches the environment used for normal work. This simulates the
    important "fresh clone -> setup" scenario.

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

. (Join-Path $RepositoryRoot "settings.ps1")
$Settings = Get-ProjectSettings -RepositoryRoot $RepositoryRoot

$requiredFiles = @(
    "requirements.txt",
    "settings.json",
    "settings.ps1",
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

$testId = [Guid]::NewGuid().ToString("N")

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("WhisperX-clean-install-" + $testId)

# The test builds its own throwaway environment. It must never touch the
# developer's real one, which the copied setup.ps1 would otherwise resolve from
# the copied settings.json.
$testEnvironmentRoot = Resolve-ConfiguredPath `
    -Path $Settings.test.environmentPath `
    -RepositoryRoot $RepositoryRoot

$testEnvironment = Join-Path $testEnvironmentRoot $testId

$productionEnvironment = Resolve-ConfiguredPath `
    -Path $Settings.environment.venvPath `
    -RepositoryRoot $RepositoryRoot

function Test-PathOverlap {
    # True when the two paths are the same, or one contains the other.
    param(
        [Parameter(Mandatory)][string]$First,
        [Parameter(Mandatory)][string]$Second
    )

    $a = $First.TrimEnd('\') + '\'
    $b = $Second.TrimEnd('\') + '\'

    return $a.StartsWith($b, [StringComparison]::OrdinalIgnoreCase) -or
           $b.StartsWith($a, [StringComparison]::OrdinalIgnoreCase)
}

# Compare the configured roots, not the per-run folder: a per-run folder nested
# inside the normal environment would still be building into it.
if (Test-PathOverlap -First $testEnvironmentRoot -Second $productionEnvironment) {
    throw @"
Clean-install test aborted: the isolated test environment would be created
inside, or on top of, the environment used for normal work.

    test.environmentPath   $testEnvironmentRoot
    environment.venvPath   $productionEnvironment

Set test.environmentPath in settings.json to a location that does not overlap
environment.venvPath.
"@
}

New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
Write-Host "Temporary test directory:   $testRoot"
Write-Host "Isolated test environment:  $testEnvironment"

try {
    # Exclude repository metadata, any environment left inside the repository by
    # an earlier version, and the developer's local settings override - the
    # override would otherwise follow the copy and redirect this test at their
    # real environment.
    $null = robocopy `
        $RepositoryRoot `
        $testRoot `
        /E `
        /XD ".git" ".venv" "env" `
        /XF "settings.local.json" `
        /NFL /NDL /NJH /NJS /NP

    if ($LASTEXITCODE -gt 7) {
        throw "Failed to copy repository to temporary test directory. Robocopy exit code: $LASTEXITCODE"
    }

    $testSetupScript = Join-Path $testRoot "01-Environment-Setup\setup.ps1"

    Write-Host ""
    Write-Host "--- Running setup.ps1 in isolated repository ---" -ForegroundColor Yellow

    # Use Bypass only for the child test process so a downloaded/cloned script
    # is not blocked by the host's RemoteSigned policy.
    # -EnvironmentPath is what keeps this test off the developer's real
    # environment. Without it the copied setup would resolve the shared path
    # from the copied settings.json.
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $testSetupScript `
        -PythonCommand $PythonCommand `
        -EnvironmentPath $testEnvironment

    if ($LASTEXITCODE -ne 0) {
        throw "setup.ps1 failed with exit code $LASTEXITCODE."
    }

    $venvPython = Get-VenvPython -EnvironmentPath $testEnvironment

    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
        throw "Clean-install test failed: no Python was created at $testEnvironment."
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
    # Retain the evidence. Previously this message was printed but the finally
    # block deleted the directory anyway.
    $KeepTemp = $true

    Write-Host "Temporary test directory retained for diagnosis: $testRoot" -ForegroundColor Yellow
    Write-Host "Isolated test environment retained for diagnosis: $testEnvironment" -ForegroundColor Yellow
    throw
}
finally {
    if (-not $KeepTemp) {
        foreach ($path in @($testRoot, $testEnvironment)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Every failure path throws before this point. Exit 0 explicitly so a trailing native
# command (git, robocopy) cannot leave a non-zero $LASTEXITCODE behind on success.
exit 0
