# 01 — Environment Setup

This directory prepares a Windows computer to run the WhisperX Transcription project.

## Normal entry point

For a fresh clone, use:

```powershell
.\01-Environment-Setup\setup.ps1
```

Run this from the repository root.

You normally run this **once per computer**.

## What setup.ps1 does

The setup entry point automates the environment preparation:

1. Checks Python.
2. Checks FFmpeg and attempts automatic installation when supported.
3. Creates the virtual environment at the configured external location.
4. Installs dependencies from `requirements.txt`.
5. Configures the Hugging Face token when required.
6. Verifies WhisperX and its diarization API.

After successful setup, the transcription pipeline can be run without manually activating the virtual environment.

## Hugging Face token

Speaker diarization requires Hugging Face authentication.

If no token is already configured, `setup.ps1` prompts the user for it.

Alternatively:

```powershell
.\01-Environment-Setup\setup.ps1 -HFToken "hf_..."
```

Never commit the token to the repository.

## Individual scripts

The directory also contains these building blocks:

```text
01-check-prerequisites.ps1
02-create-environment.ps1
03-install-whisperx.ps1
04-verify-installation.ps1
```

For normal users, **do not run these individually**. Use:

```powershell
.\01-Environment-Setup\setup.ps1
```

The individual scripts remain useful for maintenance and troubleshooting.

## Virtual environment

The environment is created **outside the repository**, at the path configured in
`settings.json`:

```text
%LOCALAPPDATA%\WhisperX-Transcription\venv
```

Keeping it outside means a multi-gigabyte runtime never enters version control or a synced
folder, and re-cloning the repository does not mean rebuilding it.

Override the location for a single run:

```powershell
.\01-Environment-Setup\setup.ps1 -EnvironmentPath "E:\ml-envs\whisperx"
```

Or permanently for this machine, in `settings.local.json`:

```json
{
  "environment": { "venvPath": "E:\\ml-envs\\whisperx" }
}
```

If an old `.venv`, `env` or `whisperx-env` still exists inside the repository, setup reports
it. Nothing uses it any more, and it is safe to delete once the new environment works.

## After setup

Run:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```
