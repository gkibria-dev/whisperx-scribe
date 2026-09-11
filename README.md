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

## Project structure

```text
WhisperX-Transcription/
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
├── tests/
├── README-testing.md
├── requirements.txt
├── .gitignore
└── LICENSE
```

> `.venv` is intentionally not stored in Git. Every computer creates its own environment.

## Quick start

### New computer

After cloning the repository, open PowerShell at the repository root and run:

```powershell
.\01-Environment-Setup\setup.ps1
```

This is the **one-time environment setup**.

The setup process prepares the local Python environment, installs the required packages, checks FFmpeg, configures Hugging Face authentication when required, and verifies WhisperX.

Then transcribe an audio file:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

That's the normal workflow. You do **not** need to activate `.venv` manually.

### Existing computer

If the repository's `.venv` is already prepared and WhisperX is working, go directly to:

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

- **Python not found** — install Python and make `python` available in PATH.
- **FFmpeg not found** — install FFmpeg and make it available in PATH.
- **Hugging Face authentication/model access** — complete the required Hugging Face account/token setup.
- **First run is slow** — models may need to be downloaded.
- **CPU inference is slow** — CPU transcription can take substantially longer than GPU inference.

## Documentation

- `01-Environment-Setup/README.md` — environment setup details.
- `02-Transcription-Pipeline/README.md` — pipeline and script details.
- `README-testing.md` — automated testing information.

## License

See `LICENSE`.
