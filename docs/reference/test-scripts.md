# Reference: test scripts

The four PowerShell tests in `tests\`. Each one exits non-zero and prints a red `... TEST FAILED`
banner on failure. No test writes generated files inside the repository.

| Script | Covers | Needs the WhisperX environment | Network | Typical duration |
|---|---|---|---|---|
| `test-settings.ps1` | Settings layering, path resolution, secret scan, Git ignore rules | No | No | Seconds |
| `test-docs.ps1` | Every script option and setting has a reference heading here | No | No | Seconds |
| `test-clean-install.ps1` | Fresh copy of the repository → `setup.ps1` → working environment | Builds its own | Yes | Long: a full environment install |
| `test-pipeline.ps1` | `run_pipeline.ps1` end to end on the bundled two-speaker sample | Yes | First run only | Minutes on CPU |

| Setting | Used by |
|---|---|
| `test.outputDirectory` | `test-pipeline.ps1` |
| `test.keepOutput` | `test-pipeline.ps1` |
| `test.environmentPath` | `test-clean-install.ps1` |
| `environment.venvPath` | `test-pipeline.ps1` (the environment it runs), `test-clean-install.ps1` (overlap check) |

## `test-settings.ps1`

```powershell
.\tests\test-settings.ps1
```

Takes no parameters.

| Assertion group | Checks |
|---|---|
| Layer 1 | Built-in defaults apply when no settings file exists |
| Layer 2 | `settings.json` overrides defaults, and absent keys keep defaults |
| Layer 3 | `settings.local.json` overrides only the keys it supplies, while sibling and unrelated keys are kept |
| Path resolution | `%LOCALAPPDATA%` expands, the result is absolute, and `Get-VenvPython` appends `Scripts\python.exe` |
| No secrets | Neither settings file matches `hf_token`, `token`, `secret`, `password`, `credential` or `api_key`/`api-key`/`apikey` |
| Real configuration | `settings.json` exists, and the environment path is absolute and outside the repository. When `settings.local.json` exists, every key's effective value matches its source file. |
| Git | `settings.local.json` is ignored and untracked, and `settings.json` is not ignored. Skipped when `git` is unavailable. |
| Consumers | `setup.ps1` and `run_pipeline.ps1` load `settings.ps1`, read `environment.venvPath`, call `Resolve-ConfiguredPath`, and have no repository-local environment fallback |

Layering assertions use synthetic files in `%TEMP%\WhisperX-settings-<guid>`, which are deleted
afterwards. When `settings.local.json` is absent, the assertions specific to it are reported as
skipped, because the file is optional.

## `test-docs.ps1`

```powershell
.\tests\test-docs.ps1
```

Takes no parameters.

| Code source | Reference file |
|---|---|
| `01-Environment-Setup\*.ps1`, `param()` block | `docs\reference\setup-scripts.md` |
| `02-Transcription-Pipeline\*.ps1`, `param()` block | `docs\reference\run-pipeline.md` |
| `02-Transcription-Pipeline\scripts\*.py`, `add_argument(` string literals | `docs\reference\pipeline-stage-scripts.md` |
| `tests\*.ps1`, `param()` block | `docs\reference\test-scripts.md` |
| Keys of `Get-DefaultProjectSettings` in `settings.ps1`, as `section.key` | `docs\reference\settings.md` |

Heading rules. A heading counts only when its entire text is a single code span, and
headings inside fenced code blocks are ignored.

| Heading | Meaning |
|---|---|
| ``## `name.ps1` `` | Starts the section for that script |
| ``### `-Name` `` | A parameter of the current script section, spelled as on the command line (`-Model`, `--compute-type`, `audio`) |
| ``### `section.key` `` | A setting (in `settings.md`, in any section) |
| Any other `##` heading | Ends the current script section |

| Failure line | Meaning |
|---|---|
| `<file> exists` | The reference file is missing |
| `<script> has a section` | No `## ` section for a script. Its options are listed. |
| `Undocumented option: <name>` | The option is in the code but has no `###` heading |
| `Documented option not in the script: <name>` | A `###` heading names an option the script no longer has |
| `section '<name>' names an existing script` | A `##` section names a script that does not exist |
| `Undocumented setting: <key>` / `Documented setting not in Get-DefaultProjectSettings: <key>` | The same checks for settings |

Only option names are compared. Defaults, types and descriptions are not checked.

## `test-clean-install.ps1`

```powershell
.\tests\test-clean-install.ps1 [-PythonCommand <string>] [-KeepTemp]
```

| Order | Action |
|---|---|
| 1 | Checks that the required project files exist and that `-PythonCommand` is on `PATH` |
| 2 | Stops if `test.environmentPath` and `environment.venvPath` are the same, or one contains the other |
| 3 | Copies the repository to `%TEMP%\WhisperX-clean-install-<id>`, excluding `.git`, `.venv`, `env` and `settings.local.json` |
| 4 | Runs the copied `setup.ps1 -PythonCommand <PythonCommand> -EnvironmentPath <test.environmentPath>\<id>` in a child `powershell.exe -ExecutionPolicy Bypass` |
| 5 | Imports `torch`, `whisperx` and `DiarizationPipeline` in the new environment |
| 6 | Deletes the temporary copy and the test environment |

On failure, both directories are kept and their paths are printed. The copied `setup.ps1` runs
the Hugging Face step, so it prompts when `HF_TOKEN` is not already set. It also handles
FFmpeg, so FFmpeg does not have to be on `PATH` before the test runs.

### `-PythonCommand`

| | |
|---|---|
| Type | string |
| Default | `python` (hard-coded, `environment.pythonCommand` is not read) |
| Accepted values | A Python 3.10 or newer command on `PATH`, for example `py` |

Passed to the copied `setup.ps1` as `-PythonCommand`.

### `-KeepTemp`

| | |
|---|---|
| Type | switch |
| Default | off |

Keeps the temporary repository copy and the test environment after a successful run.

## `test-pipeline.ps1`

```powershell
.\tests\test-pipeline.ps1 [-Audio <string>] [-OutputDirectory <string>] [-Model <string>]
    [-Device <string>] [-ComputeType <string>] [-Language <string>] [-KeepOutput]
```

Runs `run_pipeline.ps1` in a child `powershell.exe -ExecutionPolicy Bypass` with
`-MinSpeakers 2 -MaxSpeakers 2` and an explicit `-Model`, `-Device`, `-ComputeType` and
`-OutputDirectory`. It then checks that:

1. the four output files exist and are not empty;
2. the raw, aligned and diarized JSON each contain at least one segment;
3. the diarized segments have at least two distinct speakers, including `SPEAKER_00` and `SPEAKER_01`;
4. the final transcript contains `SPEAKER_00` and `SPEAKER_01`.

`tests\data\sample-2-speakers.expected.txt` must exist, but its content is not compared.

Because the model, device and compute type are always passed explicitly, `pipeline.model`,
`pipeline.device`, `pipeline.computeType`, `pipeline.minSpeakers` and `pipeline.maxSpeakers`
do not affect this test. `pipeline.language` does apply when `-Language` is empty.

### `-Audio`

| | |
|---|---|
| Type | string |
| Default | `tests\data\sample-2-speakers.wav` |
| Accepted values | Path to an audio file with at least two speakers. A relative path is resolved against the current PowerShell location. |

### `-OutputDirectory`

| | |
|---|---|
| Type | string |
| Default | `<test.outputDirectory>\<audio stem>-<yyyyMMdd-HHmmss>` |
| Accepted values | Directory path. Created if it does not exist. |

**The directory is deleted recursively after a successful run**, including when it is supplied
explicitly and already contains other files, unless `-KeepOutput` or `test.keepOutput` is set.
It is kept after a failed run.

### `-Model`

| | |
|---|---|
| Type | string |
| Default | `medium` (hard-coded, `pipeline.model` is not read) |
| Accepted values | As `run_pipeline.ps1 -Model` ([run-pipeline.md](run-pipeline.md#-model)) |

### `-Device`

| | |
|---|---|
| Type | string |
| Default | `cpu` (hard-coded, `pipeline.device` is not read) |
| Accepted values | `cpu`, `cuda` |

### `-ComputeType`

| | |
|---|---|
| Type | string |
| Default | `int8` (hard-coded, `pipeline.computeType` is not read) |
| Accepted values | As `run_pipeline.ps1 -ComputeType` ([run-pipeline.md](run-pipeline.md#-computetype)) |

### `-Language`

| | |
|---|---|
| Type | string |
| Default | empty. `run_pipeline.ps1` then uses `pipeline.language`, or auto-detects. |
| Accepted values | As `run_pipeline.ps1 -Language` ([run-pipeline.md](run-pipeline.md#-language)) |

### `-KeepOutput`

| | |
|---|---|
| Type | switch |
| Default | off. Also on when `test.keepOutput` is `true`. |

Keeps the output directory after a successful run.
