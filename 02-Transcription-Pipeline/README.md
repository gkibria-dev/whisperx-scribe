# 02 — Transcription Pipeline

The reusable audio transcription pipeline.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

You do not need to activate the environment manually. The runner uses the environment
configured in `settings.json` (`environment.venvPath`), which lives outside the repository. If
that environment does not exist, the runner stops and tells you to run
`01-Environment-Setup\setup.ps1`. It does not fall back to an environment inside the repository.

Model, device, compute type, language and speaker-count defaults also come from `settings.json`.
Any argument passed on the command line overrides them.

## Documentation

| You want to | Go to |
|---|---|
| Run the pipeline for the first time | [Tutorial: your first transcript](../docs/tutorials/first-transcription.md) |
| Look up a parameter or its allowed values | [Reference: `run_pipeline.ps1`](../docs/reference/run-pipeline.md) |
| Look up a stage script's arguments | [Reference: pipeline stage scripts](../docs/reference/pipeline-stage-scripts.md) |
| Know what is in each output file | [Reference: output files](../docs/reference/output-files.md) |
| Set the language | [How-to](../docs/how-to/set-transcription-language.md) |
| Make a run faster or more accurate | [How-to](../docs/how-to/choose-model-and-speed.md) |
| Set the number of speakers | [How-to](../docs/how-to/set-speaker-count.md) |
| Change where transcripts are written | [How-to](../docs/how-to/choose-output-location.md) |
| Debug one stage on its own | [How-to](../docs/how-to/run-a-single-stage.md) |
| Understand the four-stage design | [Explanation](../docs/explanation/how-the-pipeline-works.md) |

## Stages

```text
Audio ──▶ transcribe.py ──▶ *_raw.json ──▶ align_and_merge.py ──▶ *_aligned.json
                                                                        │
       *_final.txt ◀── finalize.py ◀── *_diarized.json ◀── diarize.py ───┘
```

| Stage | Script | Adds |
|---|---|---|
| 1 | `transcribe.py` | The text, in chunks, and the language |
| 2 | `align_and_merge.py` | Word-level timings |
| 3 | `diarize.py` | Speaker labels such as `SPEAKER_00`. Requires a Hugging Face token. |
| 4 | `finalize.py` | The readable, timestamped transcript |

Each script is a standalone command-line program that reads files and writes files. They never
import each other. For normal use, run `run_pipeline.ps1` rather than the Python scripts.

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
`settings.json` to collect them in one configured folder instead, or pass `-OutputDirectory` to
redirect a single run.

The intermediate JSON files are kept on purpose: they are what you look at when a stage
misbehaves.

## Input audio

Any format the underlying WhisperX/FFmpeg stack can decode, including `.wav`, `.m4a` and `.mp3`.
