# WhisperX Transcription

A reusable Windows PowerShell pipeline for converting an audio recording into a
time-aligned, speaker-labelled transcript.

The project is designed so that a new user can clone the repository, complete
the one-time environment setup, and then process any supported audio file with
one command.

## What it does

The pipeline performs four processing stages:

```text
Audio
  |
  v
1. Transcription
  |
  +--> *_raw.json
  |
  v
2. Word alignment
  |
  +--> *_aligned.json
  |
  v
3. Speaker diarization
  |
  +--> *_diarized.json
  |
  v
4. Finalization
  |
  +--> *_final.txt
```

The final TXT file is the human-readable transcript. The intermediate JSON files
preserve information needed by later stages.

## Quick start

After the environment has been prepared:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav"
```

You do not need to activate the virtual environment manually if the project
contains `.venv`, `env`, or `whisperx-env` at the repository root.

The script automatically finds the environment.

### Hugging Face token

Speaker diarization requires a Hugging Face access token.

You have three options:

1. Supply it as a parameter:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 `
    "C:\Recordings\interview.wav" `
    -HFToken "hf_your_token_here"
```

2. Set `HF_TOKEN` in the environment.

3. Do nothing. If no token is available, the script securely asks for it.

For normal interactive use, option 3 is the simplest:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav"
```

The token is not written into the repository or generated transcript files.

## Output

For:

```text
C:\Recordings\interview.wav
```

the default output is:

```text
C:\Recordings\interview_raw.json
C:\Recordings\interview_aligned.json
C:\Recordings\interview_diarized.json
C:\Recordings\interview_final.txt
```

You can change the output directory:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 `
    "C:\Recordings\interview.wav" `
    -OutputDirectory "C:\Recordings\output"
```

## Useful options

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 `
    "C:\Recordings\interview.wav" `
    -Model medium `
    -Language en `
    -Device cpu `
    -ComputeType int8
```

If `-Language` is omitted, WhisperX can detect the language.

If the number of speakers is known:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 `
    "C:\Recordings\interview.wav" `
    -MinSpeakers 2 `
    -MaxSpeakers 2
```

## Repository structure

```text
WhisperX/
|
+-- 01-Environment-Setup/
|   +-- ...
|
+-- 02-Transcription-Pipeline/
|   +-- run_pipeline.ps1
|   +-- scripts/
|       +-- transcribe.py
|       +-- align_and_merge.py
|       +-- diarize.py
|       +-- finalize.py
|
+-- tests/
+-- requirements.txt
+-- .gitignore
+-- README.md
```

## Environment setup

Environment setup is a separate, one-time phase.

It installs Python dependencies, FFmpeg requirements, WhisperX, and prepares
Hugging Face authentication/model access.

Once setup is complete, the normal workflow is simply:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.m4a"
```

## Pipeline stages

### 1. `transcribe.py`

Converts speech to text and creates:

```text
*_raw.json
```

### 2. `align_and_merge.py`

Adds word-level timestamps and creates:

```text
*_aligned.json
```

### 3. `diarize.py`

Determines speaker turns and assigns anonymous labels such as:

```text
SPEAKER_00
SPEAKER_01
```

It creates:

```text
*_diarized.json
```

### 4. `finalize.py`

Converts the diarized JSON into an easy-to-read transcript:

```text
*_final.txt
```

Example:

```text
[00:00:19 - 00:00:43] SPEAKER_00
Yeah. All right. Cool. So, yeah, I will just go through with you...

[00:00:43 - 00:02:26] SPEAKER_01
Okay. So, my experience is on a .NET-based framework...
```

Speaker numbers are anonymous. The system does not know the real names of the
people in the recording.

## Why separate scripts?

Each stage has a clear responsibility and produces an intermediate artifact.

This means a later stage can be rerun without repeating earlier, expensive
processing.

For example, if diarization fails, you do not need to transcribe and align the
audio again.

## Privacy

Audio recordings and generated transcripts are intended to remain local.

Do not commit private recordings, generated transcripts, model caches, or
authentication tokens to GitHub.

The included `.gitignore` excludes the common generated/private files.

## Important Windows note

WhisperX uses PyTorch, TorchCodec, FFmpeg, and other native dependencies.
Compatibility between those components matters.

If you see a TorchCodec/FFmpeg warning, it is separate from Hugging Face
authentication. A warning is not necessarily the reason the pipeline stopped.

The pipeline reports the actual failing stage and stops when a stage returns a
non-zero exit code.

## License

See `LICENSE` for the license of this project's own code.

WhisperX, Whisper/faster-whisper, PyTorch, pyannote and their model weights have
their own licenses and terms. Review those separately before redistribution.
