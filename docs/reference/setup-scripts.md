# Reference: environment setup scripts

The scripts in `01-Environment-Setup\`. `setup.ps1` is the public entry point and does not call
the numbered scripts. The numbered scripts are separate maintenance tools, and several of them
overlap with `setup.ps1`.

| Script | Purpose | Reads settings |
|---|---|---|
| `setup.ps1` | Complete one-time setup | `environment.venvPath`, `environment.pythonCommand` |
| `01-check-prerequisites.ps1` | Checks Python and FFmpeg on `PATH` | No |
| `02-create-environment.ps1` | Creates the virtual environment | `environment.venvPath`, `environment.pythonCommand` |
| `03-install-whisperx.ps1` | Installs pinned CPU PyTorch and the requirements | `environment.venvPath` |
| `04-verify-installation.ps1` | Imports and reports the installed packages | `environment.venvPath` |

Environment paths are resolved with `Resolve-ConfiguredPath`, which expands `%VAR%` and resolves
relative paths against the repository root. See [settings.md](settings.md).

## `setup.ps1`

```powershell
.\01-Environment-Setup\setup.ps1 [-PythonCommand <string>] [-EnvironmentPath <string>]
    [-RequirementsFile <string>] [-SkipHuggingFaceToken] [-HFToken <string>]
```

| Step | Console heading | Action |
|---|---|---|
| — | `Note: an unused environment remains inside the repository` | Shown for each `.venv`, `env` or `whisperx-env` in the repository that contains `Scripts\python.exe`. Advisory only. |
| 1 | `[1/6] Checking Python...` | Runs `<PythonCommand> --version` |
| 2 | `[2/6] Checking FFmpeg...` | Searches `PATH`, `%LOCALAPPDATA%\Microsoft\WinGet`, `%LOCALAPPDATA%\Programs`, `%LOCALAPPDATA%\Microsoft`, `%ProgramFiles%` and `%ProgramFiles(x86)%` for a working `ffmpeg.exe`. If none is found, runs `winget install --id Gyan.FFmpeg.Shared` and searches again, whatever exit code winget returns. The FFmpeg directory is added to the process `PATH`. |
| 3 | `[3/6] Creating virtual environment...` | Runs `<PythonCommand> -m venv <EnvironmentPath>`, creating parent directories. An existing environment is reused. |
| 4 | `[4/6] Installing dependencies...` | `pip install --upgrade pip`, then `pip install -r <RequirementsFile>` |
| 5 | `[5/6] Checking Hugging Face authentication...` | See `-HFToken` and `-SkipHuggingFaceToken` |
| 6 | `[6/6] Verifying WhisperX...` | Imports `whisperx` and `whisperx.diarize.DiarizationPipeline` and prints the WhisperX version |

Any failed step stops the script with an error message.

### `-PythonCommand`

| | |
|---|---|
| Type | string |
| Default | `python` |
| Default from | `environment.pythonCommand` |
| Accepted values | A command or full path to a Python 3.10 or newer interpreter, for example `python`, `py`, `C:\Python312\python.exe` |

Used only in steps 1 and 3. Every later step uses the environment's own `python.exe`.

### `-EnvironmentPath`

| | |
|---|---|
| Type | string |
| Default | `%LOCALAPPDATA%\WhisperX-Scribe\venv` |
| Default from | `environment.venvPath` |
| Accepted values | Directory path. `%VAR%` is expanded, and a relative path is resolved against the repository root. |

Applies to this run only. `run_pipeline.ps1` still uses `environment.venvPath`, so an
environment created elsewhere is used only when the setting points to it.

### `-RequirementsFile`

| | |
|---|---|
| Type | string |
| Default | `<repository root>\requirements.txt` |
| Accepted values | Path to a pip requirements file. A relative path is resolved against the current directory, not the repository root. |
| Error | `Requirements file not found: <path>` |

### `-SkipHuggingFaceToken`

| | |
|---|---|
| Type | switch |
| Default | off |

Skips step 5 entirely and prints `Hugging Face token check skipped.` Takes precedence over
`-HFToken`. Diarization still needs a token at pipeline run time.

### `-HFToken`

| | |
|---|---|
| Type | string |
| Default | empty |
| Accepted values | A Hugging Face access token |

Step 5 behavior:

| Condition | Result |
|---|---|
| `-SkipHuggingFaceToken` | Nothing is read or written |
| `-HFToken` supplied | The trimmed value is written to the user-level `HF_TOKEN` environment variable and the current process |
| `HF_TOKEN` set in the process or at user level | Reused and reported as `HF_TOKEN is already configured.` |
| None of the above | Hidden prompt. The answer is written to the user-level `HF_TOKEN`, and an empty answer stops setup. |

A user-level variable is visible to PowerShell windows opened afterwards. The token is never printed.

## `01-check-prerequisites.ps1`

```powershell
.\01-Environment-Setup\01-check-prerequisites.ps1
```

Takes no parameters.

| Check | Result |
|---|---|
| `python` on `PATH` | Error if missing: `Python was not found on PATH. Install Python 3.10-3.13 and reopen PowerShell.` |
| `ffmpeg` on `PATH` | Error if missing: `FFmpeg was not found on PATH. Install an FFmpeg shared build and reopen PowerShell.` |
| FFmpeg major version > 7 | Warning that TorchCodec 0.7 may fail to load, and that FFmpeg 7.x shared libraries are recommended |

It always checks the `python` command, whatever `environment.pythonCommand` is set to. It
does not search the WinGet or Program Files locations that `setup.ps1` searches.

## `02-create-environment.ps1`

```powershell
.\01-Environment-Setup\02-create-environment.ps1 [-PythonCommand <string>] [-EnvironmentPath <string>]
```

Creates the virtual environment with `<PythonCommand> -m venv`. If `Scripts\python.exe` already
exists, it prints `The environment already exists. Nothing to create.` and exits `0`.

### `-PythonCommand`

| | |
|---|---|
| Type | string |
| Default | `python` |
| Default from | `environment.pythonCommand` |
| Accepted values | A Python 3.10 or newer command or path |

### `-EnvironmentPath`

| | |
|---|---|
| Type | string |
| Default | `%LOCALAPPDATA%\WhisperX-Scribe\venv` |
| Default from | `environment.venvPath` |
| Accepted values | Directory path, resolved as for `setup.ps1 -EnvironmentPath` |

## `03-install-whisperx.ps1`

```powershell
.\01-Environment-Setup\03-install-whisperx.ps1 [-UpgradePip] [-EnvironmentPath <string>]
```

| Order | Command run in the environment |
|---|---|
| 1 | `pip install --upgrade pip`, only with `-UpgradePip` |
| 2 | `pip install --upgrade torch==2.8.0 torchaudio==2.8.0 torchvision==0.23.0 --index-url https://download.pytorch.org/whl/cpu` |
| 3 | `pip install --upgrade -r requirements.txt` |

The environment must already exist (`Virtual environment not found at <path>. Run 02-create-environment.ps1 first.`).
The script changes the current PowerShell location to the repository root.

`setup.ps1` does not run step 2. It lets pip resolve PyTorch from `requirements.txt`.

### `-UpgradePip`

| | |
|---|---|
| Type | switch |
| Default | off |

Upgrades pip before installing packages.

### `-EnvironmentPath`

| | |
|---|---|
| Type | string |
| Default | `%LOCALAPPDATA%\WhisperX-Scribe\venv` |
| Default from | `environment.venvPath` |
| Accepted values | Path to an existing environment, resolved as for `setup.ps1 -EnvironmentPath` |

## `04-verify-installation.ps1`

```powershell
.\01-Environment-Setup\04-verify-installation.ps1 [-EnvironmentPath <string>]
```

| Check | Output on success | Error on failure |
|---|---|---|
| `import torch` | `PyTorch: <version>`, `CUDA available: <True/False>` | `PyTorch verification failed.` |
| `import torchcodec` | `TorchCodec import OK: <version>` | `TorchCodec verification failed.` |
| `import whisperx` | `WhisperX import OK: <path>` | `WhisperX verification failed.` |
| `from whisperx.diarize import DiarizationPipeline` | `DiarizationPipeline OK` | `WhisperX diarization import failed.` |

The environment must already exist. The script changes the current PowerShell location to the
repository root.

### `-EnvironmentPath`

| | |
|---|---|
| Type | string |
| Default | `%LOCALAPPDATA%\WhisperX-Scribe\venv` |
| Default from | `environment.venvPath` |
| Accepted values | Path to an existing environment, resolved as for `setup.ps1 -EnvironmentPath` |
