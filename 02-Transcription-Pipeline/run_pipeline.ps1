param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Audio,

    # Empty values fall back to the pipeline defaults in settings.json.
    [string]$Model = "",
    [string]$Language = "",
    [string]$Device = "",
    [string]$ComputeType = "",
    [string]$AlignModel = "",

    [Nullable[int]]$MinSpeakers = $null,
    [Nullable[int]]$MaxSpeakers = $null,

    [string]$OutputDirectory = "",

    # Optional. If omitted, the script uses HF_TOKEN from the environment.
    # If neither is available, the script securely prompts for the token.
    [string]$HFToken = ""
)

$ErrorActionPreference = "Stop"

# Repository root is the parent of 02-Transcription-Pipeline.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Scripts = Join-Path $PSScriptRoot "scripts"

. (Join-Path $RepoRoot "settings.ps1")
$Settings = Get-ProjectSettings -RepositoryRoot $RepoRoot

# Unset parameters take their defaults from settings.json; an explicitly passed
# argument always wins.
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = $Settings.pipeline.model }
if ([string]::IsNullOrWhiteSpace($Device)) { $Device = $Settings.pipeline.device }
if ([string]::IsNullOrWhiteSpace($ComputeType)) { $ComputeType = $Settings.pipeline.computeType }
if ([string]::IsNullOrWhiteSpace($Language)) { $Language = [string]$Settings.pipeline.language }
if ([string]::IsNullOrWhiteSpace($AlignModel)) { $AlignModel = [string]$Settings.pipeline.alignModel }

if (-not $MinSpeakers.HasValue -and $null -ne $Settings.pipeline.minSpeakers) {
    $MinSpeakers = [int]$Settings.pipeline.minSpeakers
}

if (-not $MaxSpeakers.HasValue -and $null -ne $Settings.pipeline.maxSpeakers) {
    $MaxSpeakers = [int]$Settings.pipeline.maxSpeakers
}

# The configured external environment is the only one used. There is
# deliberately no fallback to a repository-local .venv - keeping the Python
# runtime out of the repository is the point of this layout.
$EnvironmentPath = Resolve-ConfiguredPath -Path $Settings.environment.venvPath -RepositoryRoot $RepoRoot
$Python = Get-VenvPython -EnvironmentPath $EnvironmentPath

if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw @"
WhisperX environment was not found.

Expected: $EnvironmentPath

Run the environment setup first:
    .\01-Environment-Setup\setup.ps1

The Python environment is intentionally stored outside the repository.
Its location is configured in settings.json (environment.venvPath) and can
be overridden per machine in settings.local.json.
"@
}

if (-not (Test-Path -LiteralPath $Scripts -PathType Container)) {
    throw "Pipeline scripts folder not found: $Scripts"
}

$AudioPath = (Resolve-Path -LiteralPath $Audio -ErrorAction Stop).Path
$AudioFile = Get-Item -LiteralPath $AudioPath

if ($AudioFile.PSIsContainer) {
    throw "Audio path points to a directory, not a file: $AudioPath"
}

# Output resolution: an explicit -OutputDirectory wins; otherwise the configured
# output mode decides. The default mode is "beside-audio", which writes the
# transcripts next to the source recording exactly as this pipeline always has.
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    if ($Settings.output.mode -eq "directory") {
        $OutputDirectory = Resolve-ConfiguredPath -Path $Settings.output.directory -RepositoryRoot $RepoRoot
    }
    else {
        $OutputDirectory = $AudioFile.DirectoryName
    }
}
else {
    $OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

# Resolve Hugging Face authentication before starting the expensive
# diarization stage. The token is kept only in this PowerShell process and
# passed to child Python processes through HF_TOKEN.
$PromptedForToken = $false

if (-not [string]::IsNullOrWhiteSpace($HFToken)) {
    $env:HF_TOKEN = $HFToken
}
elseif ([string]::IsNullOrWhiteSpace($env:HF_TOKEN)) {
    Write-Host ""
    Write-Host "Speaker diarization requires a Hugging Face access token." -ForegroundColor Yellow
    Write-Host "Your token will not be displayed while you type it." -ForegroundColor Yellow

    $SecureToken = Read-Host "Enter your Hugging Face token" -AsSecureString

    if (-not $SecureToken) {
        throw "No Hugging Face token was supplied."
    }

    $TokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken)

    try {
        $env:HF_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($TokenPointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($TokenPointer)
    }

    $PromptedForToken = $true
}

function Invoke-PythonScript {
    param(
        [string]$ScriptName,
        [string[]]$Arguments
    )

    $ScriptPath = Join-Path $Scripts $ScriptName

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Pipeline script not found: $ScriptPath"
    }

    Write-Host ""
    Write-Host "=== $ScriptName ===" -ForegroundColor Cyan

    & $Python $ScriptPath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE."
    }
}

$Stem = [System.IO.Path]::GetFileNameWithoutExtension($AudioFile.Name)

$Raw = Join-Path $OutputDirectory "${Stem}_raw.json"
$Aligned = Join-Path $OutputDirectory "${Stem}_aligned.json"
$Diarized = Join-Path $OutputDirectory "${Stem}_diarized.json"
$Final = Join-Path $OutputDirectory "${Stem}_final.txt"

try {
    Write-Host ""
    Write-Host "WhisperX Scribe Pipeline" -ForegroundColor Green
    Write-Host "Audio:       $AudioPath"
    Write-Host "Environment: $Python"
    Write-Host "Output:      $OutputDirectory"

    $TranscribeArgs = @(
        $AudioPath,
        "--model", $Model,
        "--device", $Device,
        "--compute-type", $ComputeType,
        "--output", $Raw
    )

    if (-not [string]::IsNullOrWhiteSpace($Language)) {
        $TranscribeArgs += @("--language", $Language)
    }

    Invoke-PythonScript "transcribe.py" $TranscribeArgs

    $AlignArgs = @(
        $AudioPath,
        $Raw,
        "--device", $Device,
        "--output", $Aligned
    )

    if (-not [string]::IsNullOrWhiteSpace($AlignModel)) {
        $AlignArgs += @("--align-model", $AlignModel)
    }

    Invoke-PythonScript "align_and_merge.py" $AlignArgs

    $DiarizeArgs = @(
        $AudioPath,
        $Aligned,
        "--device", $Device,
        "--output", $Diarized
    )

    if ($MinSpeakers.HasValue) {
        $DiarizeArgs += @("--min-speakers", $MinSpeakers.Value)
    }

    if ($MaxSpeakers.HasValue) {
        $DiarizeArgs += @("--max-speakers", $MaxSpeakers.Value)
    }

    Invoke-PythonScript "diarize.py" $DiarizeArgs

    Invoke-PythonScript "finalize.py" @(
        $Diarized,
        "--output", $Final
    )

    Write-Host ""
    Write-Host "=== Pipeline complete ===" -ForegroundColor Green
    Write-Host "Raw:       $Raw"
    Write-Host "Aligned:   $Aligned"
    Write-Host "Diarized:  $Diarized"
    Write-Host "Final:     $Final"
}
finally {
    # If the token was entered interactively, do not leave it in the
    # PowerShell process after the pipeline finishes.
    if ($PromptedForToken) {
        Remove-Item Env:HF_TOKEN -ErrorAction SilentlyContinue
    }
}
