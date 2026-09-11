$ErrorActionPreference = "Stop"

Write-Host "=== WhisperX prerequisites ===" -ForegroundColor Cyan

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "Python was not found on PATH. Install Python 3.10-3.13 and reopen PowerShell."
}

$pythonVersion = & python --version 2>&1
Write-Host "Python: $pythonVersion"

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Error "FFmpeg was not found on PATH. Install an FFmpeg shared build and reopen PowerShell."
}

$ffmpegVersion = & ffmpeg -version 2>&1 | Select-Object -First 1
Write-Host "FFmpeg: $ffmpegVersion"

$versionText = ($ffmpegVersion -join " ")
if ($versionText -match 'ffmpeg version\s+(\d+)') {
    $major = [int]$Matches[1]
    if ($major -gt 7) {
        Write-Warning "FFmpeg $major detected. This project pins TorchCodec 0.7 for the PyTorch 2.8 baseline; use FFmpeg 7.x shared libraries if TorchCodec loading fails."
    }
}

Write-Host "Prerequisite check passed." -ForegroundColor Green
