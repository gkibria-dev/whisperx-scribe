# Reference: `run_pipeline.ps1`

The command-line interface of the transcription pipeline. For the settings that supply its
defaults, see [settings.md](settings.md). For the files it produces, see
[output-files.md](output-files.md).

## `run_pipeline.ps1`

| | |
|---|---|
| Path | `02-Transcription-Pipeline\run_pipeline.ps1` |
| Runs | `transcribe.py`, `align_and_merge.py`, `diarize.py`, `finalize.py`, in that order ([pipeline-stage-scripts.md](pipeline-stage-scripts.md)) |
| Python used | `<environment.venvPath>\Scripts\python.exe`. No other environment is searched. |
| Stops when | the environment is missing, the audio path is missing or is a directory, no Hugging Face token is available, or any stage exits with a non-zero code |

### Syntax

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 [-Audio] <string>
    [-Model <string>] [-Language <string>] [-Device <string>] [-ComputeType <string>]
    [-AlignModel <string>] [-MinSpeakers <int>] [-MaxSpeakers <int>]
    [-OutputDirectory <string>] [-HFToken <string>]
```

### Value resolution

For `-Model`, `-Language`, `-Device`, `-ComputeType`, `-AlignModel`, `-MinSpeakers` and `-MaxSpeakers`:

| Order | Source |
|---|---|
| 1 | The command-line argument, when it is not empty |
| 2 | `settings.local.json` |
| 3 | `settings.json` |
| 4 | Built-in defaults in `settings.ps1` |

An empty string argument (for example `-Language ""`) counts as not supplied, so the value
comes from the settings.

### `-Audio`

| | |
|---|---|
| Type | string |
| Required | Yes |
| Position | 0 (the parameter name can be omitted) |
| Default | None |
| Accepted values | Path to an existing audio file. A relative path is resolved against the current PowerShell location. |
| Supported formats | Any format FFmpeg can decode, for example `.wav`, `.mp3`, `.m4a` |

The audio file stem (file name without extension) is used to name every output file.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav"
```

### `-Model`

| | |
|---|---|
| Type | string |
| Default | `medium` |
| Default from | `pipeline.model` |
| Passed to | `transcribe.py --model` |
| Accepted values | `tiny`, `tiny.en`, `base`, `base.en`, `small`, `small.en`, `medium`, `medium.en`, `large-v1`, `large-v2`, `large-v3`, `large` (= `large-v3`), `large-v3-turbo`, `turbo` (= `large-v3-turbo`), `distil-small.en`, `distil-medium.en`, `distil-large-v2`, `distil-large-v3`, `distil-large-v3.5`, or a path to a local CTranslate2 model directory |

Names ending in `.en` are English-only models. For these, WhisperX presets the language to `en`,
so no language detection runs when `-Language` is empty. The model is downloaded on first use to the Hugging Face cache
([environment-variables.md](environment-variables.md#hf_home)).

Accepted names come from faster-whisper 1.2.1, which is installed by `whisperx==3.8.6`.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -Model large-v3
```

### `-Language`

| | |
|---|---|
| Type | string |
| Default | empty (auto-detect) |
| Default from | `pipeline.language` |
| Passed to | `transcribe.py --language`, only when not empty |
| Accepted values | A language code (not a language name). Without `-AlignModel`, only codes that have a default alignment model: `ar`, `ca`, `cs`, `da`, `de`, `el`, `en`, `es`, `eu`, `fa`, `fi`, `fr`, `gl`, `he`, `hi`, `hr`, `hu`, `id`, `it`, `ja`, `ka`, `ko`, `lv`, `ml`, `nl`, `nn`, `no`, `pl`, `pt`, `ro`, `ru`, `sk`, `sl`, `sv`, `te`, `tl`, `tr`, `uk`, `ur`, `vi`, `zh` |

| Value | Behavior |
|---|---|
| Empty | Whisper detects the language from the first 30 seconds of audio and logs `Detected language: <code> (<probability>) in first 30s of audio`. |
| Supported code | Detection is skipped and the code is used for transcription and alignment. |
| Language name, for example `english` | Stage 1 fails with `'english' is not a valid language code`. |
| Whisper language without a default alignment model, for example `bn` | Stage 1 succeeds. Stage 2 fails with `ERROR: Could not load an alignment model for language 'bn'.` unless `-AlignModel` is set. |

Whisper transcribes 100 languages, and WhisperX 3.8.6 has default alignment models for the 41
codes listed above. Because the pipeline always runs alignment, any other language needs
`-AlignModel`.

Stage 1 logs `No language specified, language will be detected for each audio file` while the
model loads, whatever `-Language` says, because the value is applied after that point. The line
that reports actual detection is `Detected language:`, which appears only when no language was
supplied.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -Language en
```

### `-Device`

| | |
|---|---|
| Type | string |
| Default | `cpu` |
| Default from | `pipeline.device` |
| Passed to | `transcribe.py`, `align_and_merge.py`, `diarize.py` as `--device` |
| Accepted values | `cpu`, `cuda` |

`cuda` requires a CUDA-enabled PyTorch build and an NVIDIA GPU. The environment built by
`setup.ps1` contains a CPU-only PyTorch build (`torch 2.8.0+cpu`).

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -Device cuda -ComputeType float16
```

### `-ComputeType`

| | |
|---|---|
| Type | string |
| Default | `int8` |
| Default from | `pipeline.computeType` |
| Passed to | `transcribe.py --compute-type` only. Alignment and diarization do not use it. |
| Accepted values on `cpu` | `int8`, `int8_float32`, `int16`, `float32` |
| Accepted values on `cuda` | Depends on the GPU. List them with `python -c "import ctranslate2; print(ctranslate2.get_supported_compute_types('cuda'))"` in the environment. |

The CPU list comes from `ctranslate2.get_supported_compute_types("cpu")` with CTranslate2 4.8.2.
An unsupported value makes stage 1 fail while loading the model.

Higher precision needs more memory. A supported type can still fail at model load when there is
not enough free RAM for that model size, with `RuntimeError: mkl_malloc: failed to allocate memory`.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -ComputeType float32
```

### `-AlignModel`

| | |
|---|---|
| Type | string |
| Default | empty (the WhisperX default for the language) |
| Default from | `pipeline.alignModel` |
| Passed to | `align_and_merge.py --align-model`, only when not empty |
| Accepted values | A Hugging Face model ID of a wav2vec2 CTC model fine-tuned on the audio's language, or a torchaudio pipeline name |

The alignment model used in stage 2. It is required for languages that have no default
alignment model (see [`-Language`](#-language)). It replaces the default for languages that do
have one. The model is downloaded on first use to the Hugging Face cache.

The model's vocabulary must cover the script Whisper writes for that language. Characters the
model does not know get no word timing, and words without timings get no speaker.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "call.m4a" -Language bn -AlignModel arijitx/wav2vec2-xls-r-300m-bengali
```

### `-MinSpeakers`

| | |
|---|---|
| Type | integer, nullable |
| Default | not set |
| Default from | `pipeline.minSpeakers` |
| Passed to | `diarize.py --min-speakers`, only when set |
| Accepted values | Integer ≥ 1, and not greater than `-MaxSpeakers` |

The minimum number of speakers the diarization model may assign. An invalid value is
rejected by `diarize.py`, which runs after transcription and alignment have completed.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -MinSpeakers 2
```

### `-MaxSpeakers`

| | |
|---|---|
| Type | integer, nullable |
| Default | not set |
| Default from | `pipeline.maxSpeakers` |
| Passed to | `diarize.py --max-speakers`, only when set |
| Accepted values | Integer ≥ 1, and not less than `-MinSpeakers` |

The maximum number of speakers the diarization model may assign. Setting `-MinSpeakers` and
`-MaxSpeakers` to the same value fixes the speaker count.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -MinSpeakers 2 -MaxSpeakers 2
```

### `-OutputDirectory`

| | |
|---|---|
| Type | string |
| Default | empty |
| Accepted values | Directory path. Created if it does not exist. |

| Condition | Output location |
|---|---|
| `-OutputDirectory` supplied | That directory |
| Not supplied, `output.mode` is `directory` | `output.directory`, after `%VAR%` expansion |
| Not supplied, any other `output.mode` | The directory containing the audio file |

A relative `-OutputDirectory` is resolved with .NET `GetFullPath`, which uses the process
working directory, and that can differ from the current PowerShell location. Absolute paths are
not affected. Existing output files with the same names are overwritten.

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -OutputDirectory "D:\Transcripts"
```

### `-HFToken`

| | |
|---|---|
| Type | string |
| Default | empty |
| Accepted values | A Hugging Face access token (`hf_...`) |

Token resolution, performed before any stage runs:

| Order | Source | After the run |
|---|---|---|
| 1 | `-HFToken` | Copied to `$env:HF_TOKEN` and left set in the PowerShell session |
| 2 | `HF_TOKEN` environment variable | Unchanged |
| 3 | Interactive prompt with hidden input | Removed from `$env:HF_TOKEN` when the pipeline ends, whether it succeeds or fails |

Stages receive the token through the `HF_TOKEN` environment variable. It is never printed.
An empty prompt answer stops the run with `No Hugging Face token was supplied.`

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "interview.wav" -HFToken "hf_..."
```

## Console output

| Line | When |
|---|---|
| `WhisperX Scribe Pipeline`, `Audio:`, `Environment:`, `Output:` | Start of the run |
| `=== <script>.py ===` | Before each stage |
| `=== Pipeline complete ===` followed by the four output paths | After the last stage |
| `<script>.py failed with exit code <n>.` | A stage failed. Later stages do not run. |

## Error messages

| Message | Cause |
|---|---|
| `WhisperX environment was not found.` | `<environment.venvPath>\Scripts\python.exe` does not exist |
| `Pipeline scripts folder not found: <path>` | `02-Transcription-Pipeline\scripts` is missing |
| `Audio path points to a directory, not a file: <path>` | `-Audio` is a directory |
| `Cannot find path '<path>' because it does not exist.` | `-Audio` does not exist |
| `No Hugging Face token was supplied.` | The token prompt was left empty |
| `Pipeline script not found: <path>` | A stage script is missing |
