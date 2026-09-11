# Phase 1 — Environment Setup

This folder prepares a Windows PC to run the WhisperX transcription pipeline.

**Do this once per PC/environment.** After it succeeds, normally you only need to activate `.venv` and run the scripts in `02-Transcription-Pipeline` for new audio files.

## Prerequisites

- Windows 10/11
- PowerShell
- Python 3.10–3.13; Python 3.11 is a conservative choice for this project
- Internet access during installation/model download
- Enough free disk space for Python packages and Whisper models
- FFmpeg **shared libraries** available on PATH. For the pinned TorchCodec/PyTorch combination in this project, use an FFmpeg 7.x shared build to avoid the FFmpeg 9 / older TorchCodec mismatch encountered on some Windows setups.

## Step 1 — Check prerequisites

From the repository root:

```powershell
.\01-Environment-Setup\01-check-prerequisites.ps1
```

This checks Python and FFmpeg and reports what was found. If it reports a problem, fix that before continuing.

Check Python manually if needed:

```powershell
python --version
ffmpeg -version
```

## Step 2 — Create the virtual environment

```powershell
.\01-Environment-Setup\02-create-environment.ps1
```

This creates:

```text
.venv/
```

inside the project. The folder is ignored by Git.

Activate it:

```powershell
.\.venv\Scripts\Activate.ps1
```

If PowerShell blocks activation, run once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then activate again.

## Step 3 — Install WhisperX

With `.venv` activated:

```powershell
.\01-Environment-Setup\03-install-whisperx.ps1
```

The project uses a known-good CPU-oriented dependency baseline:

- WhisperX 3.8.6
- PyTorch 2.8.0 CPU wheels
- TorchAudio 2.8.0
- TorchVision 0.23.0
- TorchCodec 0.7.0

The important reason for pinning TorchCodec is compatibility with the PyTorch generation used here. TorchCodec's compatibility table pairs the 0.7 series with PyTorch 2.8. citeturn0search0

## Step 4 — Hugging Face account and diarization access

Speaker diarization uses pyannote models hosted on Hugging Face. WhisperX's documentation requires a Hugging Face read token and acceptance of the user agreement for the diarization model. citeturn0search6

1. Create/sign in to a Hugging Face account.
2. Create a **Read** access token.
3. Accept the access terms for the diarization models requested by the installed WhisperX/pyannote version.
4. Do **not** put the token in this Git repository.

For this project, the safest workflow is to keep the token in the PowerShell environment for the current session:

```powershell
$env:HF_TOKEN = "hf_your_token_here"
```

Verify that it exists without printing the token:

```powershell
if ($env:HF_TOKEN) { "HF_TOKEN is set" } else { "HF_TOKEN is NOT set" }
```

For a permanent user-level environment variable, Windows PowerShell can also use:

```powershell
[Environment]::SetEnvironmentVariable("HF_TOKEN", "hf_your_token_here", "User")
```

After setting it permanently, open a new PowerShell window.

## Step 5 — Verify the installation

With `.venv` activated:

```powershell
.\01-Environment-Setup\04-verify-installation.ps1
```

The verification checks the Python imports used by the pipeline, including WhisperX, Torch, TorchCodec and the diarization pipeline.

## FFmpeg note for Windows

WhisperX/pyannote uses audio decoding, and TorchCodec relies on FFmpeg libraries. TorchCodec's Windows installation guidance specifically calls out FFmpeg shared builds. citeturn0search0

If `ffmpeg -version` works but WhisperX reports:

```text
Could not load libtorchcodec
```

check the FFmpeg major version and the TorchCodec/PyTorch versions together. Do not assume that installing a newer FFmpeg automatically fixes the problem.

## Models and cache

WhisperX downloads model files the first time a model is used. The cache can become several GB depending on the models used.

You may keep the Hugging Face cache outside the repository. For example, set `HF_HOME` before running the pipeline:

```powershell
$env:HF_HOME = "E:\AI\hf-cache"
```

The path is only an example; choose a drive/folder with sufficient free space.

If you want this setting to persist for your user account:

```powershell
[Environment]::SetEnvironmentVariable("HF_HOME", "E:\AI\hf-cache", "User")
```

Open a new PowerShell after changing a persistent environment variable.

## Do not copy the environment to another PC

Do not commit or copy `.venv/` as the project's portable environment. Recreate it on the target PC using these setup steps. The Python environment contains machine/platform-specific binaries.

Likewise, model caches are local data rather than source code. A new PC can download the required models when they are first used.

## When Phase 1 is complete

You should be able to run:

```powershell
python -c "import whisperx; print('WhisperX import OK')"
```

and:

```powershell
python -c "from whisperx.diarize import DiarizationPipeline; print('DiarizationPipeline OK')"
```

Then proceed to:

```text
02-Transcription-Pipeline/README.md
```
