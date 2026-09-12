<#
.SYNOPSIS
    Runs and validates the complete WhisperX transcription pipeline.

.DESCRIPTION
    Executes the production run_pipeline.ps1 against a known sample audio file,
    then validates the generated raw, aligned, diarized and final outputs.

    The test does not duplicate the pipeline implementation. It calls the same
    run_pipeline.ps1 used by normal users.

    By default the test uses:
        tests\data\sample-2-speakers.wav

    The test expects the sample to contain two distinct speakers. Therefore it
    runs the production pipeline with --min-speakers 2 and --max-speakers 2 and
    verifies that both SPEAKER_00 and SPEAKER_01 appear in the diarized output.

.PARAMETER Audio
    Optional path to the test audio file.

.PARAMETER OutputDirectory
    Optional directory for generated test outputs. Defaults to the directory
    containing the source audio file, matching the normal pipeline behavior.

.PARAMETER Model
    WhisperX model to use. Default: medium.

.PARAMETER Device
    Inference device. Default: cpu.

.PARAMETER ComputeType
    WhisperX compute type. Default: int8.

.PARAMETER Language
    Optional language code. Leave empty for automatic language detection.

.PARAMETER KeepOutput
    Keep generated output files after the test.

.EXAMPLE
    .\tests\test-pipeline.ps1

.EXAMPLE
    .\tests\test-pipeline.ps1 -KeepOutput

.EXAMPLE
    .\tests\test-pipeline.ps1 -Audio ".\tests\data\sample-2-speakers.wav"
#>

[CmdletBinding()]
param(
    [string]$Audio = "",
    [string]$OutputDirectory = "",
    [string]$Model = "medium",
    [string]$Device = "cpu",
    [string]$ComputeType = "int8",
    [string]$Language = "",
    [switch]$KeepOutput
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$PipelineScript = Join-Path $RepositoryRoot "02-Transcription-Pipeline\run_pipeline.ps1"

. (Join-Path $RepositoryRoot "settings.ps1")
$Settings = Get-ProjectSettings -RepositoryRoot $RepositoryRoot

if (-not (Test-Path -LiteralPath $PipelineScript -PathType Leaf)) {
    throw "Pipeline script not found: $PipelineScript"
}

if ([string]::IsNullOrWhiteSpace($Audio)) {
    $Audio = Join-Path $RepositoryRoot "tests\data\sample-2-speakers.wav"
}

$AudioPath = (Resolve-Path -LiteralPath $Audio -ErrorAction Stop).Path
$AudioFile = Get-Item -LiteralPath $AudioPath

if ($AudioFile.PSIsContainer) {
    throw "Audio path points to a directory, not a file: $AudioPath"
}

$expectedPath = Join-Path $RepositoryRoot "tests\data\sample-2-speakers.expected.txt"

if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
    throw "Expected transcript file not found: $expectedPath"
}

$stem = [System.IO.Path]::GetFileNameWithoutExtension($AudioFile.Name)

# Generated test artifacts never go inside the repository. Each run gets its own
# folder under the configured external test output directory, so runs cannot
# collide and cleanup can remove the whole folder safely.
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $TestOutputRoot = Resolve-ConfiguredPath `
        -Path $Settings.test.outputDirectory `
        -RepositoryRoot $RepositoryRoot

    $OutputDirectory = Join-Path $TestOutputRoot ("{0}-{1}" -f $stem, (Get-Date -Format "yyyyMMdd-HHmmss"))
}
else {
    $OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$KeepOutputRequested = $KeepOutput.IsPresent

if (-not $KeepOutputRequested -and $Settings.test.keepOutput) {
    $KeepOutputRequested = $true
}

$raw = Join-Path $OutputDirectory "${stem}_raw.json"
$aligned = Join-Path $OutputDirectory "${stem}_aligned.json"
$diarized = Join-Path $OutputDirectory "${stem}_diarized.json"
$final = Join-Path $OutputDirectory "${stem}_final.txt"

$environmentPath = Resolve-ConfiguredPath `
    -Path $Settings.environment.venvPath `
    -RepositoryRoot $RepositoryRoot

$python = Get-VenvPython -EnvironmentPath $environmentPath

Write-Host "=== WhisperX pipeline integration test ===" -ForegroundColor Cyan
Write-Host "Repository: $RepositoryRoot"
Write-Host "Audio:      $AudioPath"
Write-Host "Output:     $OutputDirectory"

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "WhisperX environment not found at $environmentPath. Run .\01-Environment-Setup\setup.ps1 first."
}

Write-Host ""
Write-Host "--- Running production pipeline ---" -ForegroundColor Yellow

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $PipelineScript,
    $AudioPath,
    "-Model", $Model,
    "-Device", $Device,
    "-ComputeType", $ComputeType,
    "-MinSpeakers", "2",
    "-MaxSpeakers", "2",
    "-OutputDirectory", $OutputDirectory
)

if (-not [string]::IsNullOrWhiteSpace($Language)) {
    $arguments += @("-Language", $Language)
}

try {
    & powershell.exe @arguments

    if ($LASTEXITCODE -ne 0) {
        throw "run_pipeline.ps1 failed with exit code $LASTEXITCODE."
    }

    Write-Host ""
    Write-Host "--- Validating pipeline outputs ---" -ForegroundColor Yellow

    foreach ($path in @($raw, $aligned, $diarized, $final)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Expected pipeline output was not created: $path"
        }

        if ((Get-Item -LiteralPath $path).Length -eq 0) {
            throw "Pipeline output is empty: $path"
        }
    }

    $rawJson = Get-Content -LiteralPath $raw -Raw -Encoding UTF8 | ConvertFrom-Json
    $alignedJson = Get-Content -LiteralPath $aligned -Raw -Encoding UTF8 | ConvertFrom-Json
    $diarizedJson = Get-Content -LiteralPath $diarized -Raw -Encoding UTF8 | ConvertFrom-Json
    $finalText = Get-Content -LiteralPath $final -Raw -Encoding UTF8

    if ($null -eq $rawJson.segments -or @($rawJson.segments).Count -eq 0) {
        throw "Raw transcription contains no segments."
    }

    if ($null -eq $alignedJson.segments -or @($alignedJson.segments).Count -eq 0) {
        throw "Aligned transcription contains no segments."
    }

    if ($null -eq $diarizedJson.segments -or @($diarizedJson.segments).Count -eq 0) {
        throw "Diarized transcription contains no segments."
    }

    $speakerNames = @(
        $diarizedJson.segments |
        ForEach-Object { $_.speaker } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )

    if ($speakerNames.Count -lt 2) {
        throw "Diarization validation failed. Expected at least 2 speakers, found: $($speakerNames -join ', ')."
    }

    if ($speakerNames -notcontains "SPEAKER_00") {
        throw "Expected SPEAKER_00 was not found in diarized output."
    }

    if ($speakerNames -notcontains "SPEAKER_01") {
        throw "Expected SPEAKER_01 was not found in diarized output."
    }

    if ([string]::IsNullOrWhiteSpace($finalText)) {
        throw "Final transcript is empty."
    }

    if ($finalText -notmatch "SPEAKER_00") {
        throw "Final transcript does not contain SPEAKER_00."
    }

    if ($finalText -notmatch "SPEAKER_01") {
        throw "Final transcript does not contain SPEAKER_01."
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "PIPELINE TEST PASSED" -ForegroundColor Green
    Write-Host "Speakers detected: $($speakerNames -join ', ')" -ForegroundColor Green
    Write-Host "Raw segments:      $(@($rawJson.segments).Count)" -ForegroundColor Green
    Write-Host "Aligned segments:  $(@($alignedJson.segments).Count)" -ForegroundColor Green
    Write-Host "Diarized segments: $(@($diarizedJson.segments).Count)" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
}
catch {
    # Keep the artifacts of a failed run - they are the evidence needed to
    # diagnose it, and re-running costs several minutes of CPU inference.
    $KeepOutputRequested = $true

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "PIPELINE TEST FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    throw
}
finally {
    if ($KeepOutputRequested) {
        Write-Host ""
        Write-Host "Test output retained: $OutputDirectory" -ForegroundColor Yellow
    }
    elseif (Test-Path -LiteralPath $OutputDirectory -PathType Container) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
