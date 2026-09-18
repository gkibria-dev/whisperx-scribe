# WhisperX Scribe

Audio transcription built around WhisperX, currently for Windows (PowerShell).

The project processes an audio recording into a **time-aligned, speaker-labeled transcript**
through a simple PowerShell command.

```powershell
.\01-Environment-Setup\setup.ps1                                    # once per computer
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav" # for each recording
```

## Documentation

**New here?** Follow the [tutorial](docs/tutorials/first-transcription.md) from a fresh clone to
your first transcript.

**Doing a specific task?**

| Goal | Guide |
|---|---|
| Set the spoken language | [set-transcription-language.md](docs/how-to/set-transcription-language.md) |
| Run faster, or more accurately | [choose-model-and-speed.md](docs/how-to/choose-model-and-speed.md) |
| Tell it how many speakers there are | [set-speaker-count.md](docs/how-to/set-speaker-count.md) |
| Choose where transcripts are written | [choose-output-location.md](docs/how-to/choose-output-location.md) |
| Set up the Hugging Face token | [configure-hugging-face-token.md](docs/how-to/configure-hugging-face-token.md) |
| Change the defaults on this computer | [change-machine-defaults.md](docs/how-to/change-machine-defaults.md) |
| Move the Python environment | [move-the-python-environment.md](docs/how-to/move-the-python-environment.md) |
| Re-run one stage while debugging | [run-a-single-stage.md](docs/how-to/run-a-single-stage.md) |
| Repair a broken environment | [repair-an-environment.md](docs/how-to/repair-an-environment.md) |
| Run the tests | [run-the-tests.md](docs/how-to/run-the-tests.md) |

**Looking up an option?**

| Reference | Covers |
|---|---|
| [run-pipeline.md](docs/reference/run-pipeline.md) | Every `run_pipeline.ps1` parameter, and its allowed values |
| [setup-scripts.md](docs/reference/setup-scripts.md) | `setup.ps1` and the numbered maintenance scripts |
| [pipeline-stage-scripts.md](docs/reference/pipeline-stage-scripts.md) | The four Python stage scripts |
| [test-scripts.md](docs/reference/test-scripts.md) | The four tests |
| [settings.md](docs/reference/settings.md) | Every setting, and the resolution order |
| [environment-variables.md](docs/reference/environment-variables.md) | `HF_TOKEN` and the other variables |
| [output-files.md](docs/reference/output-files.md) | The four output files and their formats |

**Want to understand the design?**

- [How the pipeline works](docs/explanation/how-the-pipeline-works.md)
- [Why configuration is layered](docs/explanation/configuration-layering.md)
- [Why the runtime lives outside the repository](docs/explanation/runtime-outside-the-repository.md)
- [Accuracy and speed trade-offs](docs/explanation/accuracy-and-speed-trade-offs.md)

Per-directory notes: [01-Environment-Setup](01-Environment-Setup/README.md),
[02-Transcription-Pipeline](02-Transcription-Pipeline/README.md), [tests](README-testing.md).
Design and refactor plans live in [docs/plans/](docs/plans/).

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

The `_final.txt` file is the main human-readable output. The intermediate JSON files are useful
for troubleshooting and further processing. See
[reference: output files](docs/reference/output-files.md).

## Repository vs runtime files

The repository holds only source files. Everything generated — the Python environment and the
test artifacts — lives outside it, in a machine-local runtime directory.

```text
REPOSITORY                                  RUNTIME
(this folder, in Git)                       (%LOCALAPPDATA%\WhisperX-Scribe)

settings.json          ───configures───▶    venv\           the Python environment
settings.local.json                         output\         only if output.mode = directory
settings.ps1                                test-output\    test artifacts
scripts and tests                           test-venv\      the clean-install test environment
```

This keeps a multi-gigabyte environment out of version control and out of any synced folder,
and means a test run can never leave generated files inside the repository. See
[why the runtime lives outside the repository](docs/explanation/runtime-outside-the-repository.md).

## Project structure

```text
whisperx-scribe/
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
│   ├── tutorials/                 learning-oriented walkthrough
│   ├── how-to/                    goal-oriented guides
│   ├── reference/                 every option, setting and file format
│   ├── explanation/               design and trade-offs
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

| Section | Holds |
|---|---|
| `environment` | Where the Python environment lives, and which Python creates it |
| `pipeline` | Default model, device, compute type, language and speaker counts |
| `output` | Whether transcripts go beside the audio or into one folder |
| `test` | Where the tests put their artifacts and throwaway environment |

Every key, its default and its allowed values: [reference: settings](docs/reference/settings.md).

To change a value on one machine without touching the committed file, create
`settings.local.json` beside it with only the keys you want to override:

```json
{
  "environment": { "venvPath": "E:\\ml-envs\\whisperx" },
  "pipeline":    { "language": "en" }
}
```

`settings.local.json` is gitignored. Command-line arguments always win over both files, and
deleting `settings.json` is safe, because the built-in defaults match it.

**Never put a Hugging Face token, or any other secret, in these files.** Tokens are read from
the `HF_TOKEN` environment variable — see
[how-to: configure the Hugging Face token](docs/how-to/configure-hugging-face-token.md).

## Quick start

### New computer

After cloning the repository, open PowerShell at the repository root and run:

```powershell
.\01-Environment-Setup\setup.ps1
```

This is the **one-time environment setup**. It creates the Python environment at the configured
external location, installs the required packages, checks FFmpeg, configures Hugging Face
authentication when required, and verifies WhisperX.

Then transcribe an audio file:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

You do **not** need to activate the environment manually.

### Existing computer

If the environment is already prepared, go directly to:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

Step-by-step instructions for a first run, including the Hugging Face token:
[tutorial](docs/tutorials/first-transcription.md).

## Requirements

- Windows with PowerShell
- Python 3.10+
- FFmpeg (7.x shared builds are the safe choice)
- Internet access for setup and model downloads
- A Hugging Face account and token for speaker diarization

Python dependencies are listed in `requirements.txt`.

## Troubleshooting

The pipeline stops at the first stage that fails.

| Problem | What it means |
|---|---|
| `WhisperX environment was not found` | Setup has not run on this machine. The pipeline deliberately does not fall back to an environment inside the repository, so an old `.venv` here will not be used. |
| Python or FFmpeg not found | Install it and make it available on `PATH`, then reopen PowerShell |
| Hugging Face authentication or model access errors | [Configure the token](docs/how-to/configure-hugging-face-token.md) |
| First run is slow | Models are downloaded once, then cached |
| CPU inference is slow | Expected. See [accuracy and speed trade-offs](docs/explanation/accuracy-and-speed-trade-offs.md). |

Import or package errors after a working setup:
[repair an environment](docs/how-to/repair-an-environment.md).

## License

See `LICENSE`.
