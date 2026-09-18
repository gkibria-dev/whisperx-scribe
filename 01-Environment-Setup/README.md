# 01 — Environment Setup

Prepares a Windows computer to run the WhisperX Transcription project. You normally run this
**once per computer**.

```powershell
.\01-Environment-Setup\setup.ps1
```

Run it from the repository root. It:

1. checks Python;
2. checks FFmpeg, and installs it through winget when possible;
3. creates the virtual environment at the configured external location;
4. installs the dependencies from `requirements.txt`;
5. configures the Hugging Face token when one is needed;
6. verifies WhisperX and its diarization API.

Afterwards, the pipeline runs without activating anything manually.

## Documentation

| You want to | Go to |
|---|---|
| Set up for the first time, step by step | [Tutorial: your first transcript](../docs/tutorials/first-transcription.md) |
| Look up a parameter of any script here | [Reference: setup scripts](../docs/reference/setup-scripts.md) |
| Configure or replace the Hugging Face token | [How-to](../docs/how-to/configure-hugging-face-token.md) |
| Put the environment somewhere else | [How-to](../docs/how-to/move-the-python-environment.md) |
| Fix a broken environment | [How-to](../docs/how-to/repair-an-environment.md) |
| Understand why the environment is outside the repository | [Explanation](../docs/explanation/runtime-outside-the-repository.md) |

## The other scripts here

```text
01-check-prerequisites.ps1
02-create-environment.ps1
03-install-whisperx.ps1
04-verify-installation.ps1
```

These are maintenance and troubleshooting building blocks. `setup.ps1` does not call them, and
normal users do not need them. See
[reference: setup scripts](../docs/reference/setup-scripts.md) for what each one does.

## Virtual environment

The environment is created **outside the repository**, at the path configured in `settings.json`:

```text
%LOCALAPPDATA%\WhisperX-Scribe\venv
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

If an old `.venv`, `env` or `whisperx-env` still exists inside the repository, setup reports it.
Nothing uses it any more, and it is safe to delete once the new environment works.

## After setup

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```
