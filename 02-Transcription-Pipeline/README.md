# 02 — Transcription Pipeline

This directory contains the reusable audio transcription pipeline.

## Normal entry point

Use:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

You do not need to activate `.venv` manually. The PowerShell runner locates the repository's virtual environment.

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
