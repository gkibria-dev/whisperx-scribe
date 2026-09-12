# WhisperX Transcription - Environment Setup
# Run from the repository root:
#   .\01-Environment-Setup\setup.ps1
#
# Creates the Python virtual environment inside the repository.
# No developer-specific absolute paths are used.
#
# FFmpeg handling:
#   - Uses ffmpeg.exe if it is already available on PATH.
#   - If not, attempts to install FFmpeg through winget.
#   - Handles WinGet "already installed / no upgrade" results.
#   - Searches common WinGet and Windows installation locations.
#   - Adds the discovered FFmpeg directory to the current process PATH.
#
# Hugging Face:
#   - Uses HF_TOKEN if already configured.
#   - Otherwise prompts the user and stores it for the current Windows user.
#
# PowerShell execution policy:
#   On Windows, RemoteSigned may require downloaded scripts to be unblocked once:
#       Unblock-File .\01-Environment-Setup\setup.ps1
#   This is a Windows/PowerShell security setting, not a project dependency.

[CmdletBinding()]
param(
    [string]$PythonCommand = "python",
    [string]$EnvironmentName = ".venv",
    [string]$RequirementsFile = "",
    [switch]$SkipHuggingFaceToken
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDirectory

if ([string]::IsNullOrWhiteSpace($RequirementsFile)) {
    $RequirementsFile = Join-Path $RepoRoot "requirements.txt"
}

$VenvPath = Join-Path $RepoRoot $EnvironmentName
$PythonExe = Join-Path $VenvPath "Scripts\python.exe"

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$CommandName)
    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    $parts = @($machinePath, $userPath) | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }

    $env:Path = $parts -join ";"
}

function Test-FFmpeg {
    param([Parameter(Mandatory)][string]$ExecutablePath)

    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
        return $false
    }

    try {
        $null = & $ExecutablePath -version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Find-FFmpegExecutable {
    # 1. PATH
    $command = Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $source = $command.Source
        if (Test-FFmpeg -ExecutablePath $source) {
            return $source
        }
    }

    # 2. WinGet package cache.
    $wingetPackagesRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"

    if (Test-Path -LiteralPath $wingetPackagesRoot) {
        $candidate = Get-ChildItem -LiteralPath $wingetPackagesRoot `
            -Filter "ffmpeg.exe" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -ne $candidate -and (Test-FFmpeg -ExecutablePath $candidate.FullName)) {
            return $candidate.FullName
        }
    }

    # 3. WinGet installation directories are not guaranteed to have a
    # predictable package folder name, so search the user's WinGet area.
    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet"

    if (Test-Path -LiteralPath $wingetRoot) {
        $candidate = Get-ChildItem -LiteralPath $wingetRoot `
            -Filter "ffmpeg.exe" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -ne $candidate -and (Test-FFmpeg -ExecutablePath $candidate.FullName)) {
            return $candidate.FullName
        }
    }

    # 4. Common locations used by Windows FFmpeg installations.
    $commonRoots = @(
        (Join-Path $env:LOCALAPPDATA "Programs"),
        (Join-Path $env:LOCALAPPDATA "Microsoft"),
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)}
    ) | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_)
    }

    foreach ($root in $commonRoots) {
        $candidate = Get-ChildItem -LiteralPath $root `
            -Filter "ffmpeg.exe" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike "*\WindowsApps\*" -and
                $_.FullName -notlike "*\node_modules\*"
            } |
            Select-Object -First 1

        if ($null -ne $candidate -and (Test-FFmpeg -ExecutablePath $candidate.FullName)) {
            return $candidate.FullName
        }
    }

    return $null
}

function Ensure-FFmpeg {
    # Check existing installation first.
    $ffmpeg = Find-FFmpegExecutable

    if ($null -ne $ffmpeg) {
        $directory = Split-Path -Parent $ffmpeg
        if ($env:Path -notlike "*$directory*") {
            $env:Path = "$directory;$env:Path"
        }

        Write-Host "      FFmpeg available: $ffmpeg" -ForegroundColor Green
        return
    }

    Write-Host "      FFmpeg was not found. Attempting automatic installation..." -ForegroundColor Yellow

    if (-not (Test-CommandExists "winget")) {
        throw @"
FFmpeg is required but winget was not found.

Please install FFmpeg and make sure "ffmpeg" is available on PATH,
then run this setup script again.

Verify with:
    ffmpeg -version
"@
    }

    Write-Host "      Installing FFmpeg using winget..." -ForegroundColor Yellow

    # Do not use a fixed success/failure interpretation of winget's exit code.
    # Some versions return a non-zero code when a package is already installed
    # and no upgrade is available. The actual test is whether ffmpeg.exe can
    # subsequently be found and executed.
    & winget install `
        --id Gyan.FFmpeg.Shared `
        --exact `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements

    $wingetExitCode = $LASTEXITCODE

    # WinGet may update the user's PATH only after the process exits.
    Refresh-Path

    $ffmpeg = Find-FFmpegExecutable

    if ($null -ne $ffmpeg) {
        $directory = Split-Path -Parent $ffmpeg
        if ($env:Path -notlike "*$directory*") {
            $env:Path = "$directory;$env:Path"
        }

        Write-Host "      FFmpeg available: $ffmpeg" -ForegroundColor Green

        if ($wingetExitCode -ne 0) {
            Write-Host "      winget returned $wingetExitCode, but FFmpeg is usable." -ForegroundColor DarkYellow
        }

        return
    }

    # One more attempt: ask WinGet for the package location and search the
    # reported installation root if available.
    try {
        $listOutput = & winget list --id Gyan.FFmpeg.Shared --exact 2>&1 | Out-String
        if (-not [string]::IsNullOrWhiteSpace($listOutput)) {
            Write-Host "      FFmpeg package detected by winget, but ffmpeg.exe could not be located." -ForegroundColor DarkYellow
        }
    }
    catch {
        # Diagnostic only; the final error below is clearer.
    }

    throw @"
FFmpeg could not be located after the automatic installation attempt.

The winget command returned exit code $wingetExitCode.

The setup script could not find a usable ffmpeg.exe in PATH or the
standard Windows/WinGet installation locations.

Verify whether FFmpeg is available with:
    ffmpeg -version

If that command works in a newly opened PowerShell window, run setup.ps1
again.
"@
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " WhisperX Transcription - Environment Setup" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot"
Write-Host "Environment: $VenvPath"
Write-Host ""

# [1/6] Python
Write-Host "[1/6] Checking Python..." -ForegroundColor Yellow

try {
    $pythonVersion = & $PythonCommand --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed."
    }
}
catch {
    throw @"
Python was not found.

Install Python 3.10 or newer, make sure it is available on PATH,
then run this script again.

You can specify another Python command with:
    .\01-Environment-Setup\setup.ps1 -PythonCommand python
"@
}

Write-Host "      $pythonVersion" -ForegroundColor Green

# [2/6] FFmpeg
Write-Host ""
Write-Host "[2/6] Checking FFmpeg..." -ForegroundColor Yellow
Ensure-FFmpeg

# [3/6] Virtual environment
Write-Host ""
Write-Host "[3/6] Creating virtual environment..." -ForegroundColor Yellow

if (Test-Path -LiteralPath $PythonExe -PathType Leaf) {
    Write-Host "      Existing environment found." -ForegroundColor Green
}
else {
    & $PythonCommand -m venv $VenvPath

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
        throw "Failed to create virtual environment at $VenvPath."
    }

    Write-Host "      Created: $VenvPath" -ForegroundColor Green
}

# [4/6] Dependencies
Write-Host ""
Write-Host "[4/6] Installing dependencies..." -ForegroundColor Yellow

& $PythonExe -m pip install --upgrade pip

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upgrade pip."
}

if (-not (Test-Path -LiteralPath $RequirementsFile -PathType Leaf)) {
    throw "Requirements file not found: $RequirementsFile"
}

& $PythonExe -m pip install -r $RequirementsFile

if ($LASTEXITCODE -ne 0) {
    throw "Dependency installation failed. Review the pip output above."
}

Write-Host "      Dependencies installed." -ForegroundColor Green

# [5/6] Hugging Face token
Write-Host ""
Write-Host "[5/6] Checking Hugging Face authentication..." -ForegroundColor Yellow

if ($SkipHuggingFaceToken) {
    Write-Host "      Hugging Face token check skipped." -ForegroundColor DarkYellow
}
else {
    $hfToken = $env:HF_TOKEN

    if ([string]::IsNullOrWhiteSpace($hfToken)) {
        $userToken = [Environment]::GetEnvironmentVariable("HF_TOKEN", "User")

        if (-not [string]::IsNullOrWhiteSpace($userToken)) {
            $hfToken = $userToken
            $env:HF_TOKEN = $hfToken
        }
    }

    if ([string]::IsNullOrWhiteSpace($hfToken)) {
        Write-Host ""
        Write-Host "WhisperX speaker diarization requires a Hugging Face access token." -ForegroundColor Yellow
        Write-Host "Create one at https://huggingface.co/settings/tokens"
        Write-Host ""
        Write-Host "Enter the token below. Your input will not be displayed."

        $secureToken = Read-Host "Hugging Face token" -AsSecureString

        if ($secureToken.Length -eq 0) {
            throw "No Hugging Face token was supplied."
        }

        $tokenPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)

        try {
            $hfToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPtr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPtr)
        }

        if ([string]::IsNullOrWhiteSpace($hfToken)) {
            throw "No Hugging Face token was supplied."
        }

        $env:HF_TOKEN = $hfToken
        [Environment]::SetEnvironmentVariable("HF_TOKEN", $hfToken, "User")

        Write-Host "      HF_TOKEN configured for the current user." -ForegroundColor Green
    }
    else {
        Write-Host "      HF_TOKEN is already configured." -ForegroundColor Green
    }
}

# [6/6] Verify WhisperX
Write-Host ""
Write-Host "[6/6] Verifying WhisperX..." -ForegroundColor Yellow

$verification = @'
import importlib.metadata
import whisperx

print("WhisperX import OK")

try:
    from whisperx.diarize import DiarizationPipeline
    print("DiarizationPipeline import OK")
except Exception as exc:
    print(f"DiarizationPipeline import failed: {type(exc).__name__}: {exc}")
    raise SystemExit(2)

print(f"WhisperX version: {importlib.metadata.version('whisperx')}")
'@

$verification | & $PythonExe -

if ($LASTEXITCODE -ne 0) {
    throw @"
WhisperX was installed, but verification failed.

The diarization API is expected to be available through:
    from whisperx.diarize import DiarizationPipeline

Review the verification output above.
"@
}

Write-Host "      WhisperX and DiarizationPipeline are available." -ForegroundColor Green

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Environment setup completed successfully!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Virtual environment:"
Write-Host "  $VenvPath"
Write-Host ""
Write-Host "Next step:"
Write-Host '  .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"'
Write-Host ""
