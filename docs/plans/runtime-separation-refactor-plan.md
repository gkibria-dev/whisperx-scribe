# Refactor Plan: Separating Repository Files from Runtime Files

| | |
|---|---|
| **Status** | **Implemented** 2026-09-12 (see §11 for what was verified) |
| **Date** | 2026-09-12 |
| **Scope** | PowerShell scripts, configuration, `.gitignore`, documentation |
| **Explicitly out of scope** | The four Python scripts in `02-Transcription-Pipeline/scripts/` |

This document is the implementation reference for the refactor. It is self-contained: it
records the current state, the target state, every decision and its rationale, the ordered
implementation steps, and the validation criteria. Read it top to bottom before changing code.

---

## 1. Background

WhisperX-Transcription is a Windows/PowerShell project that turns an audio file into a
time-aligned, speaker-labeled transcript. It has two phases:

- `01-Environment-Setup/` — one-time, per machine. `setup.ps1` creates a Python virtual
  environment, installs dependencies, ensures FFmpeg, configures a Hugging Face token, and
  verifies WhisperX.
- `02-Transcription-Pipeline/` — `run_pipeline.ps1` orchestrates four standalone Python
  scripts that pass data to each other as files on disk:

```
audio.wav → transcribe.py      → <stem>_raw.json
          → align_and_merge.py → <stem>_aligned.json
          → diarize.py         → <stem>_diarized.json
          → finalize.py        → <stem>_final.txt
```

Two PowerShell tests exist: `tests/test-clean-install.ps1` (fresh-clone setup) and
`tests/test-pipeline.ps1` (end-to-end run against a committed two-speaker sample).

---

## 2. Current state — the problem

The repository mixes source files with runtime state.

**Problem 1 — a 2.3 GB virtual environment inside the repository.**
`.venv` lives at the repository root, and the repository sits in `D:\gDRIVE\My Code\`, a
Google Drive synced folder. Every PyTorch wheel is being synchronised to the cloud.

**Problem 2 — tests write generated files into the repository.**
`tests/test-pipeline.ps1` defaults its output directory to the source audio's own folder, so
every test run writes generated JSON and TXT into `tests/data/`. Those artifacts are only
invisible today because `.gitignore` masks them — the repository is not actually clean, it is
merely quiet.

**Problem 3 — paths are hard-coded across seven scripts,** so relocating either the
environment or the output means editing all of them.

### 2.1 Inventory of hard-coded paths to remove

| File | Hard-coded value |
|---|---|
| `01-Environment-Setup/setup.ps1:27,35` | `$EnvironmentName = ".venv"`, `$VenvPath = Join-Path $RepoRoot $EnvironmentName` |
| `01-Environment-Setup/02-create-environment.ps1:9-23` | `Test-Path ".venv"`, `python -m venv .venv` (relative, after `Set-Location`) |
| `01-Environment-Setup/03-install-whisperx.ps1:9` | `$ProjectRoot\.venv\Scripts\python.exe` |
| `01-Environment-Setup/04-verify-installation.ps1:5` | `$ProjectRoot\.venv\Scripts\python.exe` |
| `02-Transcription-Pipeline/run_pipeline.ps1:28-32` | candidate list `.venv`, `env`, `whisperx-env` under repo root |
| `02-Transcription-Pipeline/run_pipeline.ps1:5-8,65-66` | literal `medium` / `cpu` / `int8` defaults; output defaults to the audio's directory |
| `tests/test-pipeline.ps1:91` | output defaults to `$AudioFile.DirectoryName` → **writes into `tests\data\`** |
| `tests/test-pipeline.ps1:107` | `$RepositoryRoot\.venv\Scripts\python.exe` |
| `tests/test-clean-install.ps1:105` | asserts `$testRoot\.venv\Scripts\python.exe` |

**The four Python scripts contain no hard-coded paths.** They are argparse CLIs whose
`--output` defaults derive from their input filename. No Python file is modified by this plan.

---

## 3. Target state

```
REPOSITORY  (D:\gDRIVE\My Code\WhisperX-Transcription)    — code only, ~1 MB + sample wav
├── settings.json              NEW, committed — portable defaults
├── settings.local.json        NEW, gitignored, optional — machine-specific overrides
├── settings.ps1               NEW, committed — shared PowerShell settings loader
├── 01-Environment-Setup/
├── 02-Transcription-Pipeline/
├── docs/
└── tests/
    └── data/                  fixtures only, never generated output

RUNTIME  (%LOCALAPPDATA%\WhisperX-Transcription)          — never in git, never in Google Drive
├── venv/                      the 2.3 GB Python environment
├── output/                    only when output.mode = "directory"
├── test-output/               test-pipeline.ps1 artifacts
└── test-venv/                 test-clean-install.ps1 scratch environment
```

Normal transcription behavior is unchanged. For `C:\Audio\interview.wav` the pipeline still
creates, beside the source audio:

```
C:\Audio\interview_raw.json
C:\Audio\interview_aligned.json
C:\Audio\interview_diarized.json
C:\Audio\interview_final.txt
```

---

## 4. Decisions and rationale

| # | Decision | Rationale |
|---|---|---|
| D1 | Runtime root is `%LOCALAPPDATA%\WhisperX-Transcription\` | Outside Google Drive entirely; per-user; survives a repository re-clone; the standard Windows location for machine-local data. |
| D2 | **No repository-local environment fallback** | The configured external path is the *only* environment the pipeline will use. `.venv`, `env` and `whisperx-env` under the repository root are never consulted. A missing environment is a hard, explicit failure. This is the point of the refactor — the runtime is separated from the repository with no path back, and a silent fallback would quietly re-create the problem. |
| D3 | Default output stays **beside the audio file** | Preserves existing user-facing behavior. `settings.json` can switch to a central directory, but ships set to today's behavior. |
| D4 | `settings.json` committed, `settings.local.json` gitignored and merged over it | The committed file uses environment variables (`%LOCALAPPDATA%`) so it is portable to any machine. Per-machine paths go in the override without dirtying git. Same pattern as VS Code and Claude Code settings. |
| D5 | **No secrets in either settings file** | `HF_TOKEN` stays in the process environment / user environment variable exactly as today. Diarization resolution order is unchanged: `--hf-token` → `HF_TOKEN` → interactive prompt. |
| D6 | Python scripts are not modified | They are already path-clean. Rewriting working code adds risk for no benefit. |
| D7 | Clean-install test gets a doubly-enforced isolated environment | Without this, the test would silently reuse or clobber the developer's real environment. See §5.6. |
| D8 | A shared `settings.ps1` at the repository root, not a `config/` folder | A single dot-sourced loader avoids duplicating parse-and-default logic across six scripts, while keeping the root flat. |

---

## 5. Implementation steps

Implement in this order — steps 1 and 2 are prerequisites for everything after them.

### 5.1 New file: `settings.json` (repository root, committed)

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
    "keepOutput": false
  }
}
```

`output.mode` is `beside-audio` (current behavior, the default) or `directory` (use
`output.directory`). No secrets in this file — see D5.

### 5.2 New file: `settings.ps1` (repository root, dot-sourced helper)

Three public functions. Target **Windows PowerShell 5.1**: no `ConvertFrom-Json -AsHashtable`,
no `??`, no ternary operator, no `&&`/`||`.

- `Get-ProjectSettings -RepositoryRoot <path>` — reads `settings.json`, shallow-merges
  `settings.local.json` over it per section, and fills every absent key from built-in
  defaults, so a missing or partial settings file still works. Uses a private
  `Get-SettingValue` helper that walks `PSObject.Properties`.
- `Resolve-ConfiguredPath -Path <string> -RepositoryRoot <path>` — expands `%VAR%` via
  `[Environment]::ExpandEnvironmentVariables`, resolves a still-relative path against the
  repository root, and returns a full path **without requiring it to exist**.
- `Get-VenvPython -EnvironmentPath <path>` — returns `<path>\Scripts\python.exe`.

The built-in defaults must match §5.1 exactly, so deleting `settings.json` changes nothing.

### 5.3 `01-Environment-Setup/setup.ps1` — surgical changes only

- Replace the `-EnvironmentName` parameter with `-EnvironmentPath`.
- Dot-source `settings.ps1`; resolve the venv path from settings when `-EnvironmentPath` is
  not supplied.
- Create the venv's **parent** directory before running `python -m venv`.
- Add the `-HFToken` parameter. Both READMEs already document `setup.ps1 -HFToken "hf_..."`
  but the script never implemented it — only `-SkipHuggingFaceToken` exists. It seeds
  `$env:HF_TOKEN` before the existing `[5/6]` block, which then persists it unchanged.
- Print a one-line advisory if a leftover `.venv`, `env` or `whisperx-env` is found in the
  repository root, so the orphan does not sit there unnoticed.

**Do not touch** the FFmpeg discovery block, the pip install, the Hugging Face token
persistence logic, or the `[6/6]` WhisperX verification.

### 5.4 `02-Transcription-Pipeline/run_pipeline.ps1`

- Parameter defaults become empty / `$null`; fill them from `settings.pipeline` after loading
  settings, so an explicitly passed argument still wins.
- **Delete the `$EnvironmentCandidates` search entirely** (lines 26-54). Resolve the
  configured external path and use it directly — no repository-root candidates, no probing,
  no fallback (D2). If `<configured>\Scripts\python.exe` is absent, throw:

  ```
  WhisperX environment was not found.

  Expected: <resolved configured path>

  Run the environment setup first:
      .\01-Environment-Setup\setup.ps1

  The Python environment is intentionally stored outside the repository.
  Its location is configured in settings.json (environment.venvPath) and can
  be overridden per machine in settings.local.json.
  ```

- Output resolution order: explicit `-OutputDirectory` → else `output.mode = "directory"` →
  else beside the audio file (the unchanged default, D3).
- Stage invocation, `Invoke-PythonScript`, and the Hugging Face token handling are unchanged.

### 5.5 `tests/test-pipeline.ps1`

- Default output becomes `settings.test.outputDirectory` plus a per-run subfolder
  (`<stem>-<timestamp>`) — never `tests\data\`.
- The pre-flight Python check uses the configured venv.
- Make `-KeepOutput` real. Today the `finally` block is empty and output is *always* kept,
  contradicting `README-testing.md`. With output now external and per-run, default to removing
  the run folder, and keep it on `-KeepOutput` (or when `settings.test.keepOutput` is true).
- **Leave alone:** the `sample-2-speakers.expected.txt` existence check at line 82 guards a
  fixture that is never actually compared against. Out of scope — noted here only so it is not
  mistaken for a regression introduced by this refactor.

### 5.6 `tests/test-clean-install.ps1` — a real hazard that must be fixed

The test copies the repository to a temp folder and runs the *copied* `setup.ps1`. After this
refactor that copied setup would read the copied `settings.json`, resolve
`%LOCALAPPDATA%\WhisperX-Transcription\venv`, and **reuse or clobber the developer's real
production environment** — making the "fresh clone" assertion meaningless.

Fix:

- Pass an explicit `-EnvironmentPath` (a per-run folder under
  `settings.test.environmentPath`) into the child setup, and assert the venv appears *there*.
- Remove that folder in the existing `finally` block unless `-KeepTemp` was given.
- Add `settings.json` and `settings.ps1` to the `$requiredFiles` structural check.
- Add `/XF "settings.local.json"` to the robocopy call so a developer's local override cannot
  leak into the isolated test and redirect it at the developer's real environment.

Isolation is therefore enforced at two levels: the explicit argument, and the exclusion of the
settings file the child could otherwise inherit an override from.

**Keep** the existing `/XD ".git" ".venv" "env"` robocopy exclusions even though the
repository no longer creates those directories — a stale 2.3 GB `.venv` may still physically
exist during migration, and copying it to temp on every test run would be painful.

### 5.7 `01-Environment-Setup/0{2,3,4}-*.ps1`

Each resolves the configured venv path via `settings.ps1` instead of `$ProjectRoot\.venv`.
`01-check-prerequisites.ps1` contains no paths and is untouched.

### 5.8 `.gitignore`

Add `settings.local.json`. Keep the existing `.venv/`, `/output/`, `*_raw.json` etc. entries
as defensive guards — `beside-audio` mode can still legitimately write inside the repository
when a user transcribes a file that lives there.

### 5.9 Documentation

- `README.md` — new "Repository vs runtime files" section, a `settings.json` reference table,
  updated structure listing and quick start, corrected Hugging Face token section.
- `README-testing.md` — configured external test output, working `-KeepOutput`, clean-install
  isolation.
- `01-Environment-Setup/README.md` — the venv is no longer repository-local.
- `02-Transcription-Pipeline/README.md` — the runner uses the configured environment.
- `CLAUDE.md` — its "Environment discovery" section documents the old
  `.venv` → `env` → `whisperx-env` order and would otherwise be stale.

---

## 6. Interface and behavior changes

Two deliberate breaks, both to be documented in the READMEs:

1. `setup.ps1 -EnvironmentName <name>` becomes `-EnvironmentPath <path>` — "a folder name
   inside the repository" is precisely the concept being removed.
2. `run_pipeline.ps1` no longer discovers a repository-local `.venv` / `env` /
   `whisperx-env`. An existing in-repository environment stops being used, and the script
   fails with the §5.4 message until setup has run. **This is intended, not a regression.**

Every other parameter on every script is preserved. `-HFToken` is *added* to `setup.ps1` to
match what the documentation already claims.

---

## 7. Migration and cleanup

### 7.1 Migrating this working copy

The repository currently holds a working 2.3 GB `.venv` that nothing will reference after this
change. After implementation:

1. Run `.\01-Environment-Setup\setup.ps1` to build the environment at
   `%LOCALAPPDATA%\WhisperX-Transcription\venv`.
2. Verify with `.\tests\test-pipeline.ps1`.
3. **Only then** delete `D:\gDRIVE\My Code\WhisperX-Transcription\.venv` — which is also what
   stops Google Drive from syncing it.

Step 1 re-downloads PyTorch and re-resolves every wheel, so expect a long first run. See §9
for the faster alternative.

### 7.2 Ongoing cleanup behavior

| Artifact | Cleanup |
|---|---|
| `test-pipeline.ps1` run folder | Removed automatically after each run unless `-KeepOutput` or `settings.test.keepOutput` |
| `test-clean-install.ps1` temp repo copy | Removed by the existing `finally` unless `-KeepTemp` (retained on failure for diagnosis) |
| `test-clean-install.ps1` scratch venv | Removed by the same `finally` unless `-KeepTemp` — new behavior added by this refactor |
| Old in-repository `.venv` | Deleted manually once, per §7.1 |
| Verification-only `settings.local.json` | Deleted after verification steps 5 and 7 |

---

## 8. Validation criteria

The refactor is complete when all of the following pass.

1. `git status --short` → clean. Nothing generated inside the repository.
2. `.\tests\test-clean-install.ps1` → passes. During the run, confirm
   `%LOCALAPPDATA%\WhisperX-Transcription\venv` is **not** modified (compare its timestamp
   before and after) and that the temp venv is removed afterwards.
3. `.\tests\test-pipeline.ps1` → passes. Artifacts appear under
   `%LOCALAPPDATA%\WhisperX-Transcription\test-output\`, and `tests\data\` still contains only
   its three committed fixture files. Re-run with `-KeepOutput` and confirm the run folder
   survives.
4. `.\02-Transcription-Pipeline\run_pipeline.ps1 ".\tests\data\sample-2-speakers.wav"` → the
   four outputs land in `tests\data\` beside the audio, proving normal behavior is unchanged.
   Delete them afterwards.
5. **Override check** — create `settings.local.json` containing
   `{"output":{"mode":"directory"}}`, re-run step 4, and confirm the outputs move to the
   configured directory. Delete the file.
6. **Defaults check** — temporarily rename `settings.json`, run `run_pipeline.ps1`, and
   confirm it still resolves the default venv and runs. Restore the file.
7. **No-fallback check** — point `settings.local.json` at a non-existent
   `environment.venvPath` **while the old repository `.venv` is still physically present**,
   then run `run_pipeline.ps1`. It must fail with the "run setup.ps1" message and must **not**
   quietly use the in-repository `.venv`. Delete the file afterwards.

Steps 2-4 each download models and run CPU inference, so budget several minutes per run.

---

## 9. Open decision — resolve before implementing

**How to populate the new external environment.**

- **Rebuild (recommended; what §7.1 assumes)** — run `setup.ps1` and let pip resolve
  everything fresh. Guaranteed-clean result, at the cost of a full PyTorch download.
- **Move the existing folder** — `Move-Item .venv %LOCALAPPDATA%\WhisperX-Transcription\venv`.
  Minutes instead of a long download. A relocated Windows venv normally breaks its
  `Scripts\*.exe` shims and `activate` script, because paths are baked in at creation time.
  This project never activates the venv and always invokes `python.exe` by absolute path, so
  it would very likely work — but "very likely" is the caveat: if something is off, it fails
  confusingly later during a pip install rather than at move time.

This affects only how the current working copy gets from the old state to the new one. It does
not change what gets implemented.

---

## 10. Implementation instructions

Use this document as the source of truth. Concretely:

1. **Read before writing.** Inspect each target script before modifying it. Preserve working
   logic — this is a path-configuration refactor, not a rewrite.
2. **Do not modify** any file under `02-Transcription-Pipeline/scripts/`. The Python layer is
   already path-clean (D6).
3. **Follow the order in §5.** `settings.json` and `settings.ps1` must exist before any script
   is converted to use them.
4. **Honour D2 absolutely.** No script may fall back to a repository-local environment. If you
   find yourself writing a candidate list or a `Test-Path` on `$RepoRoot\.venv` as a fallback,
   that contradicts the central decision of this refactor. The only permitted references to
   those paths are the advisory message in §5.3 and the robocopy exclusions in §5.6.
5. **Target Windows PowerShell 5.1** throughout: no `-AsHashtable`, no `??`, no ternary, no
   `&&`/`||` chaining. Keep the existing conventions — `$ErrorActionPreference = "Stop"`,
   paths derived from `$PSScriptRoot`, `-LiteralPath` on filesystem tests, and `throw` with a
   multi-line here-string that tells the user what to do next.
6. **Keep secrets out of settings** (D5). `HF_TOKEN` handling is not changed by this refactor.
7. **Preserve every other script parameter.** The only interface changes permitted are the two
   listed in §6.
8. **Update the documentation in §5.9 as part of the same change**, not as a follow-up.
9. **Validate against §8** and report the actual results, including any step that fails or is
   skipped.

---

## 11. Verification results (2026-09-12)

All code, configuration and documentation changes in §5 are implemented. Every modified
PowerShell file parses cleanly.

| §8 step | Result |
|---|---|
| 1. Repo clean | **Pass** — only intended source changes; `tests\data\` holds its three fixtures and nothing else |
| 2. Clean-install test | **Not run** — needs a built environment (§9) |
| 3. Pipeline test | **Not run** — needs a built environment (§9) |
| 4. Beside-audio output | **Not run** — needs a built environment (§9) |
| 5. Override check | **Pass** — `settings.local.json` flipped `output.mode` to `directory` and resolved the configured folder; unrelated keys kept their defaults |
| 6. Defaults check | **Pass** — with `settings.json` renamed away, the built-in defaults resolved the same external path and the pipeline failed with the correct message |
| 7. **No-fallback check** | **Pass** — with a working 2.3 GB `.venv` still present in the repository, `run_pipeline.ps1` refused it and failed with the §5.4 message |

Steps 2-4 are gated on §9 only; nothing about them is known to be broken.

### Defect found and fixed during verification

The first version of the clean-install isolation guard compared the **per-run** environment
folder (`<root>\<guid>`) against `environment.venvPath`. Because of the GUID suffix the two
could never be equal, so the guard never fired: a `test.environmentPath` pointing at the real
environment was accepted and setup began building inside it. The guard now compares the
configured **roots** via a `Test-PathOverlap` helper that rejects identical paths and nesting
in either direction. Verified to fire immediately, and verified not to fire on the defaults
(`test-venv` vs `venv` do not overlap).

### Deviations from the plan as written

Both are small, and both make an existing message honest rather than changing intended design:

- **§5.5** — a *failed* pipeline test now keeps its output folder and prints the path, instead
  of deleting it. Deleting the evidence of a failure that costs minutes of CPU inference to
  reproduce would be actively unhelpful, and it matches how the clean-install test already
  treats its temp directory.
- **§5.6** — `test-clean-install.ps1` previously printed "retained for diagnosis" on failure
  while its `finally` deleted the directory anyway. That pre-existing contradiction is fixed
  so the message is now true.
