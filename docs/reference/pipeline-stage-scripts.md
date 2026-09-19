# Reference: pipeline stage scripts

The four Python scripts in `02-Transcription-Pipeline\scripts\`. `run_pipeline.ps1` runs them
in the order below ([run-pipeline.md](run-pipeline.md)). Each one is a standalone command-line
program that reads its input from disk and writes its output to disk. The scripts never import
each other.

| Order | Script | Reads | Writes |
|---|---|---|---|
| 1 | `transcribe.py` | audio | `<stem>_raw.json` |
| 2 | `align_and_merge.py` | audio, `<stem>_raw.json` | `<stem>_aligned.json` |
| 3 | `diarize.py` | audio, `<stem>_aligned.json` | `<stem>_diarized.json` |
| 4 | `finalize.py` | `<stem>_diarized.json` | `<stem>_final.txt` |

File contents are described in [output-files.md](output-files.md).

## Common behavior

| | |
|---|---|
| Interpreter | `<environment.venvPath>\Scripts\python.exe`. Stages 1–3 import `whisperx`, and `finalize.py` uses only the standard library. |
| Exit code | `0` on success. `1` on a validation error or an unhandled exception, which prints a Python traceback. |
| Errors | Written to stderr, prefixed `ERROR:` |
| Progress | `transcribe.py`, `align_and_merge.py`, and `diarize.py` print `<Stage>: NN% (elapsed <duration>, ETA <duration>)` lines to stdout as work proceeds (`diarize.py` additionally tags each line `[segmentation]` or `[embeddings]`). Lines are throttled to at most one per 5 percentage points or 15 seconds, except the first update and the final 100% update, which always print. `finalize.py` prints no percentage progress (it completes in well under a second). |
| Paths | `~` is expanded, and relative paths are resolved against the current working directory |
| Output directory | Created if it does not exist |
| Existing output | Overwritten |
| Settings files | Not read. Defaults are the `argparse` defaults listed below. |

## `transcribe.py`

Stage 1. Detects voice activity, then transcribes the audio with a Whisper model through
faster-whisper.

```text
python transcribe.py <audio> [--model MODEL] [--language LANGUAGE] [--device DEVICE]
                     [--compute-type COMPUTE_TYPE] [--output OUTPUT]
```

### `audio`

| | |
|---|---|
| Kind | positional, required |
| Type | path |
| Accepted values | An existing audio file that FFmpeg can decode |
| Error | `ERROR: Audio file not found: <path>` |

### `--model`

| | |
|---|---|
| Type | string |
| Default | `medium` |
| Accepted values | Same as `run_pipeline.ps1 -Model` ([run-pipeline.md](run-pipeline.md#-model)) |

### `--language`

| | |
|---|---|
| Type | string |
| Default | none, which means auto-detect from the first 30 seconds |
| Accepted values | Any of the 100 Whisper language codes. For the full pipeline, only codes with an alignment model ([run-pipeline.md](run-pipeline.md#-language)). |

The language used, whether given or detected, is written to the `language` key of the output.

### `--device`

| | |
|---|---|
| Type | string |
| Default | `cpu` |
| Accepted values | `cpu`, `cuda` |

### `--compute-type`

| | |
|---|---|
| Type | string |
| Default | `int8` |
| Accepted values | Same as `run_pipeline.ps1 -ComputeType` ([run-pipeline.md](run-pipeline.md#-computetype)) |

### `--output`

| | |
|---|---|
| Type | path |
| Default | `<audio directory>\<audio stem>_raw.json` |

## `align_and_merge.py`

Stage 2. Loads a wav2vec2 alignment model for the transcript's language and adds word-level
timings. By default this is the WhisperX default model for the language.

```text
python align_and_merge.py <audio> <raw_json> [--device DEVICE] [--align-model ALIGN_MODEL] [--output OUTPUT]
```

| Alignment models | Source |
|---|---|
| `de`, `en`, `es`, `fr`, `it` | torchaudio pipelines, cached under `%USERPROFILE%\.cache\torch` |
| The other 36 supported codes | Hugging Face, cached under `HF_HOME` |

### `audio`

| | |
|---|---|
| Kind | positional, required |
| Type | path |
| Accepted values | The same audio file given to stage 1 |
| Error | `ERROR: Audio file not found: <path>` |

### `raw_json`

| | |
|---|---|
| Kind | positional, required |
| Type | path |
| Accepted values | A stage 1 output file containing `segments` and a non-empty `language` |
| Errors | `ERROR: Raw transcription not found: <path>`, `ERROR: Raw transcription does not contain a language code.` |

### `--device`

| | |
|---|---|
| Type | string |
| Default | `cpu` |
| Accepted values | `cpu`, `cuda` |

### `--align-model`

| | |
|---|---|
| Type | string |
| Default | not set (the WhisperX default for the language) |
| Accepted values | A Hugging Face wav2vec2 CTC model ID, or a torchaudio pipeline name |
| Required when | The language has no default alignment model, for example `bn` |
| Error | `ERROR: Could not load an alignment model for language '<code>'.`, followed by the WhisperX reason. Exit code 1. |

The same error appears when the named model cannot be downloaded or found.

### `--output`

| | |
|---|---|
| Type | path |
| Default | Beside `raw_json`. `<name>_raw.json` becomes `<name>_aligned.json`, and any other name becomes `<stem>_aligned.json`. |

## `diarize.py`

Stage 3. Runs the `pyannote/speaker-diarization-community-1` model and assigns speaker labels
to segments and words.

```text
python diarize.py <audio> <aligned_json> [--device DEVICE] [--hf-token HF_TOKEN]
                  [--min-speakers N] [--max-speakers N] [--output OUTPUT]
```

### `audio`

| | |
|---|---|
| Kind | positional, required |
| Type | path |
| Accepted values | The same audio file given to stages 1 and 2 |
| Error | `ERROR: Audio file not found: <path>` |

### `aligned_json`

| | |
|---|---|
| Kind | positional, required |
| Type | path |
| Accepted values | A stage 2 output file |
| Error | `ERROR: Aligned transcript not found: <path>` |

### `--device`

| | |
|---|---|
| Type | string |
| Default | `cpu` |
| Accepted values | `cpu`, `cuda` |

### `--hf-token`

| | |
|---|---|
| Type | string |
| Default | none |
| Accepted values | A Hugging Face access token |

Token resolution:

| Order | Source |
|---|---|
| 1 | `--hf-token` |
| 2 | `HF_TOKEN` environment variable |
| 3 | Hidden interactive prompt, only when stdin is a terminal |

When no token is found and stdin is not a terminal, the script exits `1` with
`ERROR: Hugging Face token is required for speaker diarization.` The token is never printed.

### `--min-speakers`

| | |
|---|---|
| Type | integer |
| Default | none |
| Accepted values | ≥ 1, and ≤ `--max-speakers` when both are given |
| Errors | `ERROR: --min-speakers must be at least 1.`, `ERROR: --min-speakers cannot be greater than --max-speakers.` |

### `--max-speakers`

| | |
|---|---|
| Type | integer |
| Default | none |
| Accepted values | ≥ 1 |
| Error | `ERROR: --max-speakers must be at least 1.` |

### `--output`

| | |
|---|---|
| Type | path |
| Default | Beside `aligned_json`. `<name>_aligned.json` becomes `<name>_diarized.json`, and any other name becomes `<stem>_diarized.json`. |

## `finalize.py`

Stage 4. Converts the diarized JSON into readable speaker turns. It loads no model and needs no
audio.

```text
python finalize.py <diarized_json> [--output OUTPUT]
```

### `diarized_json`

| | |
|---|---|
| Kind | positional, required |
| Type | path |
| Accepted values | A stage 3 output file |
| Error | `ERROR: Diarized transcript not found: <path>` |

### `--output`

| | |
|---|---|
| Type | path |
| Default | Beside `diarized_json`. `<name>_diarized.json` becomes `<name>_final.txt`, and any other name becomes `<stem>_final.txt`. |
