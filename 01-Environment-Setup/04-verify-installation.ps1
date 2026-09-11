$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$Python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) {
    throw "Virtual environment not found. Run 02-create-environment.ps1 first."
}

Write-Host "=== Verifying WhisperX installation ===" -ForegroundColor Cyan

& $Python -c "import torch; print('PyTorch:', torch.__version__); print('CUDA available:', torch.cuda.is_available())"
if ($LASTEXITCODE -ne 0) { throw "PyTorch verification failed." }

& $Python -c "import torchcodec; print('TorchCodec import OK:', getattr(torchcodec, '__version__', 'version unavailable'))"
if ($LASTEXITCODE -ne 0) { throw "TorchCodec verification failed." }

& $Python -c "import whisperx; print('WhisperX import OK:', whisperx.__file__)"
if ($LASTEXITCODE -ne 0) { throw "WhisperX verification failed." }

& $Python -c "from whisperx.diarize import DiarizationPipeline; print('DiarizationPipeline OK')"
if ($LASTEXITCODE -ne 0) { throw "WhisperX diarization import failed." }

Write-Host "" 
Write-Host "Installation verification passed." -ForegroundColor Green
Write-Host "You are ready for Phase 2." -ForegroundColor Cyan
