# Reference: environment variables

Environment variables that the project reads or writes, plus those that the underlying libraries
read and that affect this project.

## Read or written by the project

### `HF_TOKEN`

| | |
|---|---|
| Contains | A Hugging Face access token |
| Needed for | Speaker diarization (`diarize.py`) |
| Must never appear in | `settings.json`, `settings.local.json`, logs, or Git |

| Script | Reads | Writes |
|---|---|---|
| `setup.ps1` | Process scope, then user scope | User scope and process, when set by `-HFToken` or the prompt |
| `run_pipeline.ps1` | Process scope | Process scope. Set from `-HFToken` or the prompt, and removed at the end only when it came from the prompt. |
| `diarize.py` | Process environment, when `--hf-token` is not given | — |
| `test-pipeline.ps1` | Inherited by the child `run_pipeline.ps1` | — |

### `LOCALAPPDATA`

| | |
|---|---|
| Typical value | `C:\Users\<user>\AppData\Local` |
| Used in | Default values of `environment.venvPath`, `output.directory`, `test.outputDirectory`, `test.environmentPath`, and the FFmpeg search in `setup.ps1` (`Microsoft\WinGet`, `Programs`, `Microsoft`) |

Any other `%NAME%` variable can be used in path settings. See [settings.md](settings.md#path-values).

### `PATH`

| Script | Looks up |
|---|---|
| `setup.ps1` | The `environment.pythonCommand` command, `ffmpeg.exe`, `winget` |
| `01-check-prerequisites.ps1` | `python`, `ffmpeg` |
| `test-clean-install.ps1` | The `-PythonCommand` command |
| All pipeline stages | FFmpeg, used indirectly to decode audio |

`setup.ps1` reloads `PATH` from the machine and user values after `winget install`, and prepends
the FFmpeg directory to the process `PATH`. It does not change the stored `PATH`.

### `ProgramFiles`, `ProgramFiles(x86)`

Searched by `setup.ps1` for `ffmpeg.exe` when FFmpeg is not on `PATH`.

## Read by libraries

### `HF_HOME`

| | |
|---|---|
| Read by | Hugging Face Hub, used by faster-whisper, pyannote and the Hugging Face alignment models |
| Default | `%USERPROFILE%\.cache\huggingface` |
| Contains | Downloaded models under `hub\`, for example `models--Systran--faster-whisper-medium` and `models--pyannote--speaker-diarization-community-1` |

Not read or set by any project script, and not related to `environment.venvPath`.

### `TORCH_HOME`

| | |
|---|---|
| Read by | PyTorch Hub, used by the torchaudio alignment models for `de`, `en`, `es`, `fr`, `it` |
| Default | `%USERPROFILE%\.cache\torch` |
| Contains | Checkpoints under `hub\checkpoints\`, for example `wav2vec2_fairseq_base_ls960_asr_ls960.pth` |

Not read or set by any project script.
