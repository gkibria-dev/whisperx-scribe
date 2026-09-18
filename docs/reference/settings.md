# Reference: settings

Configuration files for paths and pipeline defaults. Loaded by `settings.ps1` (`Get-ProjectSettings`).

## Files

| File | Location | In Git | Required |
|---|---|---|---|
| `settings.json` | Repository root | Committed | No |
| `settings.local.json` | Repository root | Ignored (`.gitignore`) | No |

Both files use the same structure. Neither may contain a token or other secret, and
`tests\test-settings.ps1` fails if one appears to.

## Resolution order

Each layer overrides the one before it, key by key:

| Order | Source |
|---|---|
| 1 | Built-in defaults (`Get-DefaultProjectSettings` in `settings.ps1`) |
| 2 | `settings.json` |
| 3 | `settings.local.json` |
| 4 | A command-line argument, where the script has a matching parameter (not empty) |

| Rule | Effect |
|---|---|
| Missing file | That layer is skipped |
| Empty file | That layer is skipped |
| Invalid JSON | The script stops with `Failed to parse settings file: <path>` |
| Missing section or key | The value from the previous layer is kept |
| Key set to `null` | The value from the previous layer is kept, so `null` cannot clear a value set in an earlier layer |
| Key set to `""` | Overrides the previous layer with an empty string |
| Unknown section or key | Ignored |

## Path values

Settings marked **path** are resolved by `Resolve-ConfiguredPath`:

| Step | Rule |
|---|---|
| 1 | `%NAME%` environment variables are expanded |
| 2 | A relative result is resolved against the repository root |
| 3 | The path does not need to exist |

In JSON, backslashes are escaped: `"E:\\envs\\whisperx"`.

## Default file

```json
{
  "environment": {
    "venvPath": "%LOCALAPPDATA%\\WhisperX-Transcription\\venv",
    "pythonCommand": "python"
  },
  "pipeline": {
    "model": "medium",
    "device": "cpu",
    "computeType": "int8",
    "language": "",
    "alignModel": "",
    "minSpeakers": null,
    "maxSpeakers": null
  },
  "output": {
    "mode": "beside-audio",
    "directory": "%LOCALAPPDATA%\\WhisperX-Transcription\\output"
  },
  "test": {
    "outputDirectory": "%LOCALAPPDATA%\\WhisperX-Transcription\\test-output",
    "environmentPath": "%LOCALAPPDATA%\\WhisperX-Transcription\\test-venv",
    "keepOutput": false,
    "model": "medium",
    "device": "cpu",
    "computeType": "int8"
  }
}
```

## `environment`

### `environment.venvPath`

| | |
|---|---|
| Type | string, **path** |
| Default | `%LOCALAPPDATA%\WhisperX-Transcription\venv` |
| Read by | `setup.ps1`, `02-create-environment.ps1`, `03-install-whisperx.ps1`, `04-verify-installation.ps1`, `run_pipeline.ps1`, `test-pipeline.ps1`, `test-clean-install.ps1` |
| Overridden by | `-EnvironmentPath` on the setup scripts only |

The Python virtual environment. `run_pipeline.ps1` uses `<venvPath>\Scripts\python.exe` and
stops if it does not exist. No other location is searched.

### `environment.pythonCommand`

| | |
|---|---|
| Type | string (a command, not resolved as a path) |
| Default | `python` |
| Read by | `setup.ps1`, `02-create-environment.ps1` |
| Overridden by | `-PythonCommand` |

The interpreter used to create the environment. It is not used to run the pipeline.

## `pipeline`

### `pipeline.model`

| | |
|---|---|
| Type | string |
| Default | `medium` |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -Model` |
| Accepted values | See [run-pipeline.md](run-pipeline.md#-model) |

### `pipeline.device`

| | |
|---|---|
| Type | string |
| Default | `cpu` |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -Device` |
| Accepted values | `cpu`, `cuda` |

### `pipeline.computeType`

| | |
|---|---|
| Type | string |
| Default | `int8` |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -ComputeType` |
| Accepted values | See [run-pipeline.md](run-pipeline.md#-computetype) |

### `pipeline.language`

| | |
|---|---|
| Type | string |
| Default | `""` (auto-detect) |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -Language` |
| Accepted values | `""`, or a language code listed in [run-pipeline.md](run-pipeline.md#-language) |

### `pipeline.alignModel`

| | |
|---|---|
| Type | string |
| Default | `""` (the WhisperX default for the language) |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -AlignModel` |
| Accepted values | `""`, or a model name described in [run-pipeline.md](run-pipeline.md#-alignmodel) |

Applies to every run, whatever the language. Set it together with `pipeline.language`.

### `pipeline.minSpeakers`

| | |
|---|---|
| Type | integer or `null` |
| Default | `null` (not passed to diarization) |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -MinSpeakers` |
| Accepted values | `null`, or an integer ≥ 1 and ≤ `pipeline.maxSpeakers` |

### `pipeline.maxSpeakers`

| | |
|---|---|
| Type | integer or `null` |
| Default | `null` (not passed to diarization) |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -MaxSpeakers` |
| Accepted values | `null`, or an integer ≥ 1 and ≥ `pipeline.minSpeakers` |

## `output`

### `output.mode`

| | |
|---|---|
| Type | string |
| Default | `beside-audio` |
| Read by | `run_pipeline.ps1` |
| Overridden by | `run_pipeline.ps1 -OutputDirectory` |

| Value | Output location |
|---|---|
| `directory` | `output.directory` |
| `beside-audio`, or any other value | The directory containing the audio file |

### `output.directory`

| | |
|---|---|
| Type | string, **path** |
| Default | `%LOCALAPPDATA%\WhisperX-Transcription\output` |
| Read by | `run_pipeline.ps1`, only when `output.mode` is `directory` |

Created if it does not exist.

## `test`

### `test.outputDirectory`

| | |
|---|---|
| Type | string, **path** |
| Default | `%LOCALAPPDATA%\WhisperX-Transcription\test-output` |
| Read by | `test-pipeline.ps1` |
| Overridden by | `test-pipeline.ps1 -OutputDirectory` |

Parent of the per-run folders `<audio stem>-<yyyyMMdd-HHmmss>`.

### `test.environmentPath`

| | |
|---|---|
| Type | string, **path** |
| Default | `%LOCALAPPDATA%\WhisperX-Transcription\test-venv` |
| Read by | `test-clean-install.ps1` |

Parent of the throwaway per-run environments. It must not be the same as `environment.venvPath`,
or contain it, or be inside it.

### `test.keepOutput`

| | |
|---|---|
| Type | boolean |
| Default | `false` |
| Read by | `test-pipeline.ps1` |
| Overridden by | `test-pipeline.ps1 -KeepOutput` (can only turn it on) |

Use the JSON literals `true` or `false`. A string such as `"false"` counts as true.

### `test.model`

| | |
|---|---|
| Type | string |
| Default | `medium` |
| Read by | `test-pipeline.ps1` |
| Overridden by | `test-pipeline.ps1 -Model` |
| Accepted values | See [run-pipeline.md](run-pipeline.md#-model) |

`test-pipeline.ps1` does not read `pipeline.model`.

### `test.device`

| | |
|---|---|
| Type | string |
| Default | `cpu` |
| Read by | `test-pipeline.ps1` |
| Overridden by | `test-pipeline.ps1 -Device` |
| Accepted values | `cpu`, `cuda` |

`test-pipeline.ps1` does not read `pipeline.device`.

### `test.computeType`

| | |
|---|---|
| Type | string |
| Default | `int8` |
| Read by | `test-pipeline.ps1` |
| Overridden by | `test-pipeline.ps1 -ComputeType` |
| Accepted values | See [run-pipeline.md](run-pipeline.md#-computetype). Must be supported on `test.device`. |

`test-pipeline.ps1` does not read `pipeline.computeType`.
