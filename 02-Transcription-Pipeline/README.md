# 02 — Transcription Pipeline

This directory contains the reusable audio transcription pipeline.

## Normal entry point

Use:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

You do not need to activate the environment manually. The PowerShell runner uses the
environment configured in `settings.json` (`environment.venvPath`), which lives outside the
repository.

If that environment does not exist, the runner stops and tells you to run
`01-Environment-Setup\setup.ps1`. It does not fall back to an environment inside the
repository — keeping the Python runtime out of version control is deliberate.

Model, device, compute type, language and speaker-count defaults also come from
`settings.json`. Any argument passed on the command line overrides them.

## Pipeline

```text
Audio
  │
  ▼
transcribe.py
  │
  ▼
*_raw.json
  │
  ▼
align_and_merge.py
  │
  ▼
*_aligned.json
  │
  ▼
diarize.py
  │
  ▼
*_diarized.json
  │
  ▼
finalize.py
  │
  ▼
*_final.txt
```

## Stage 1 — Transcription

`transcribe.py` creates:

```text
*_raw.json
```

This contains the initial transcription and segment timing.

## Stage 2 — Alignment

`align_and_merge.py` creates:

```text
*_aligned.json
```

The alignment stage adds word-level timing information.

## Stage 3 — Speaker diarization

`diarize.py` creates:

```text
*_diarized.json
```

This stage assigns speaker labels such as:

```text
SPEAKER_00
SPEAKER_01
```

It requires Hugging Face authentication.

## Stage 4 — Final transcript

`finalize.py` creates:

```text
*_final.txt
```

This is the human-readable speaker-labeled transcript.

## Example

Input:

```text
C:\Recordings\interview.wav
```

Output:

```text
C:\Recordings\interview_raw.json
C:\Recordings\interview_aligned.json
C:\Recordings\interview_diarized.json
C:\Recordings\interview_final.txt
```

Outputs land beside the source audio by default. Set `output.mode` to `directory` in
`settings.json` to collect them in one configured folder instead, or pass `-OutputDirectory`
to redirect a single run.

## Scripts

```text
scripts/
├── transcribe.py
├── align_and_merge.py
├── diarize.py
└── finalize.py
```

The scripts are separated by responsibility so individual stages can be maintained and tested independently.

For normal use, run `run_pipeline.ps1` rather than running the Python scripts manually.

## Input audio

The pipeline accepts audio formats supported by the underlying WhisperX/audio stack. Common examples include:

```text
.wav
.m4a
.mp3
```

## Intermediate files

The four outputs have different purposes:

- `_raw.json` — raw transcription
- `_aligned.json` — aligned transcription with word timing
- `_diarized.json` — speaker-assigned transcript data
- `_final.txt` — readable final transcript

Keeping the intermediate JSON files makes troubleshooting and future processing easier.
