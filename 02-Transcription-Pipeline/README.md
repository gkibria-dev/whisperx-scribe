# Phase 2 — Transcription Pipeline

This is the reusable part of the project. Once the environment in `01-Environment-Setup` is ready, use this folder to process audio recordings.

## Recommended: one command

Activate the environment from the repository root:

```powershell
.\.venv\Scripts\Activate.ps1
```

Set the Hugging Face token if it is not already configured:

```powershell
$env:HF_TOKEN = "hf_your_token_here"
```

Run:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.m4a"
```

Optional speaker-count constraints:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.m4a" -MinSpeakers 2 -MaxSpeakers 4
```

Optional model/language/device settings:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 `
    "C:\Recordings\interview.m4a" `
    -Model medium `
    -Language en `
    -Device cpu `
    -ComputeType int8
```

## What happens

The runner executes four stages and stops if a stage fails:

```text
input audio
    │
    ├── 1. transcribe.py
    │       └── *_raw.json
    │
    ├── 2. align_and_merge.py
    │       └── *_aligned.json
    │
    ├── 3. diarize.py
    │       └── *_diarized.json
    │
    └── 4. finalize.py
            └── *_final.txt
```

The JSON files are useful when debugging or building another application on top of the pipeline. The `_final.txt` file is the human-readable result.

## Run stages individually

This is recommended when troubleshooting.

### Stage 1 — transcription

```powershell
python .\02-Transcription-Pipeline\scripts\transcribe.py "C:\Recordings\interview.m4a"
```

Creates:

```text
C:\Recordings\interview_raw.json
```

### Stage 2 — alignment

```powershell
python .\02-Transcription-Pipeline\scripts\align_and_merge.py `
    "C:\Recordings\interview.m4a" `
    "C:\Recordings\interview_raw.json"
```

Creates:

```text
C:\Recordings\interview_aligned.json
```

This adds word-level timing information.

### Stage 3 — speaker diarization

Set `HF_TOKEN` first:

```powershell
$env:HF_TOKEN = "hf_your_token_here"
```

Then:

```powershell
python .\02-Transcription-Pipeline\scripts\diarize.py `
    "C:\Recordings\interview.m4a" `
    "C:\Recordings\interview_aligned.json"
```

Creates:

```text
C:\Recordings\interview_diarized.json
```

### Stage 4 — final transcript

```powershell
python .\02-Transcription-Pipeline\scripts\finalize.py `
    "C:\Recordings\interview_diarized.json"
```

Creates:

```text
C:\Recordings\interview_final.txt
```

## Changing the output location

Every stage accepts an optional `--output` argument.

Example:

```powershell
python .\02-Transcription-Pipeline\scripts\transcribe.py `
    "C:\Recordings\interview.m4a" `
    --output "C:\Transcripts\interview_raw.json"
```

The other stages follow the same pattern.

## Models

A model is downloaded when it is first used and then reused from the Hugging Face cache.

For CPU:

```powershell
--model small --compute-type int8
```

or, for higher quality at the cost of speed:

```powershell
--model medium --compute-type int8
```

The scripts do not hard-code a model path. A model name or local model path can be supplied with `--model`.

## Important: speaker labels

Diarization produces anonymous labels such as:

```text
SPEAKER_00
SPEAKER_01
```

These labels mean "different detected speakers"; they do not mean that WhisperX knows which person is Joel or Kibria.

If you know the identity of the speakers, you can manually map the labels in the final transcript after processing.

## Troubleshooting

If a command fails:

1. Do not immediately rerun the entire pipeline.
2. Check which stage failed.
3. Confirm the previous stage's output exists.
4. Run the failed stage by itself.

For example, if diarization fails but `_aligned.json` exists, rerun only Stage 3.

If the failure mentions `libtorchcodec`, check the Phase 1 FFmpeg/TorchCodec compatibility instructions.

If diarization reports an authentication or gated-model error, check your Hugging Face token and model access.
