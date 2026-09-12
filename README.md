# WhisperX Transcription

A reusable Windows-based audio transcription project built around WhisperX.

The project processes an audio recording into a **time-aligned, speaker-labeled transcript** through a simple PowerShell command.

## What this project does

The pipeline has four stages:

1. **Transcription** — converts speech to text.
2. **Alignment** — adds word-level timing.
3. **Speaker diarization** — assigns speaker labels.
4. **Finalization** — creates a human-readable transcript.

For an input such as:

```text
interview.wav
```

the pipeline creates:

```text
interview_raw.json
interview_aligned.json
interview_diarized.json
interview_final.txt
```

The `_final.txt` file is the main human-readable output.

## Repository vs runtime files

The repository holds only source files. Everything generated — the Python environment and the
test artifacts — lives outside it, in a machine-local runtime directory.

```text
REPOSITORY                                  RUNTIME
(this folder, in Git)                       (%LOCALAPPDATA%\WhisperX-Transcription)

settings.json          ───configures───▶    venv\           the Python environment
settings.local.json                         output\         only if output.mode = directory
settings.ps1                                test-output\    test artifacts
scripts and tests                           test-venv\      the clean-install test environment
```

This keeps a multi-gigabyte environment out of version control and out of any synced folder,
and means a test run can never leave generated files inside the repository.

## Project structure

```text
WhisperX-Transcription/
│
├── settings.json                  configurable paths and pipeline defaults
├── settings.local.json            optional, gitignored, per-machine overrides
├── settings.ps1                   shared settings loader used by every script
│
├── 01-Environment-Setup/
│   ├── setup.ps1
│   ├── 01-check-prerequisites.ps1
│   ├── 02-create-environment.ps1
│   ├── 03-install-whisperx.ps1
│   ├── 04-verify-installation.ps1
│   └── README.md
│
├── 02-Transcription-Pipeline/
│   ├── run_pipeline.ps1
│   ├── README.md
│   └── scripts/
│       ├── transcribe.py
│       ├── align_and_merge.py
│       ├── diarize.py
│       └── finalize.py
│
├── docs/
│   └── plans/                     design and refactor plans
│
├── tests/
├── README-testing.md
├── requirements.txt
├── .gitignore
└── LICENSE
```

> The Python environment is never stored in Git and is no longer created inside this folder.
> Every computer builds its own, at the configured location.

## Configuration

`settings.json` at the repository root holds all configurable paths and pipeline defaults. It
is committed and uses environment variables such as `%LOCALAPPDATA%`, so it works unchanged on
any machine.

| Setting | Default | Meaning |
|---|---|---|
| `environment.venvPath` | `%LOCALAPPDATA%\WhisperX-Transcription\venv` | Where the Python environment is created and looked for |
| `environment.pythonCommand` | `python` | Python used to create the environment |
| `pipeline.model` | `medium` | Default Whisper model |
| `pipeline.device` | `cpu` | Default inference device |
| `pipeline.computeType` | `int8` | Default CTranslate2 compute type |
| `pipeline.language` | *(empty)* | Language code; empty means auto-detect |
| `pipeline.minSpeakers` / `maxSpeakers` | `null` | Optional speaker-count hints |
| `output.mode` | `beside-audio` | `beside-audio` writes next to the recording; `directory` uses `output.directory` |
| `output.directory` | `%LOCALAPPDATA%\WhisperX-Transcription\output` | Used only when `output.mode` is `directory` |
| `test.outputDirectory` | `%LOCALAPPDATA%\WhisperX-Transcription\test-output` | Where the pipeline test writes its artifacts |
| `test.environmentPath` | `%LOCALAPPDATA%\WhisperX-Transcription\test-venv` | Isolated environment for the clean-install test |
| `test.keepOutput` | `false` | Keep pipeline test artifacts after a successful run |

To change a path on one machine without touching the committed file, create
`settings.local.json` beside it with only the keys you want to override:

```json
{
  "environment": { "venvPath": "E:\\ml-envs\\whisperx" }
}
```

`settings.local.json` is gitignored. Relative paths in either file are resolved against the
repository root.

**Never put a Hugging Face token, or any other secret, in these files.** Tokens are read from
the environment — see below.

Command-line arguments always win over both files. Deleting `settings.json` is safe: the
built-in defaults are identical to the values shown above.

## Quick start

### New computer

After cloning the repository, open PowerShell at the repository root and run:

```powershell
.\01-Environment-Setup\setup.ps1
```

This is the **one-time environment setup**.

The setup process creates the Python environment at the configured external location,
installs the required packages, checks FFmpeg, configures Hugging Face authentication when
required, and verifies WhisperX.

To put the environment somewhere else for this run only:

```powershell
.\01-Environment-Setup\setup.ps1 -EnvironmentPath "E:\ml-envs\whisperx"
```

Then transcribe an audio file:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

That's the normal workflow. You do **not** need to activate `.venv` manually.

### Existing computer

If the environment is already prepared and WhisperX is working, go directly to:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

## Hugging Face authentication

Speaker diarization requires a Hugging Face access token.

During environment setup, if a token is not already configured, `setup.ps1` asks the user for one.

You can also provide it explicitly:

```powershell
.\01-Environment-Setup\setup.ps1 -HFToken "hf_..."
```

Never commit a token to Git.

## Output files

For:

```text
C:\Recordings\interview.wav
```

the pipeline produces files beside the input:

```text
C:\Recordings\interview_raw.json
C:\Recordings\interview_aligned.json
C:\Recordings\interview_diarized.json
C:\Recordings\interview_final.txt
```

The intermediate JSON files are useful for troubleshooting and further processing.

To collect every transcript in one place instead, set `output.mode` to `directory` in
`settings.json`. A single run can be redirected without changing the configuration:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -OutputDirectory "D:\Transcripts"
```

## Requirements

The project is intended for Windows PowerShell and requires:

- Python 3.10+
- FFmpeg
- Internet access for setup and model downloads
- A Hugging Face account/token for speaker diarization

Python dependencies are listed in `requirements.txt`.

## Troubleshooting

The pipeline stops when a stage fails.

Common issues:

- **"WhisperX environment was not found"** — the configured environment has not been created
  yet. Run `.\01-Environment-Setup\setup.ps1`. The pipeline deliberately does not fall back to
  an environment inside the repository, so an old `.venv` sitting in this folder will not be
  used.
- **Python not found** — install Python and make `python` available in PATH.
- **FFmpeg not found** — install FFmpeg and make it available in PATH.
- **Hugging Face authentication/model access** — complete the required Hugging Face account/token setup.
- **First run is slow** — models may need to be downloaded.
- **CPU inference is slow** — CPU transcription can take substantially longer than GPU inference.

## Documentation

- `01-Environment-Setup/README.md` — environment setup details.
- `02-Transcription-Pipeline/README.md` — pipeline and script details.
- `README-testing.md` — automated testing information.
- `docs/plans/` — design and refactor plans.

## License

See `LICENSE`.
