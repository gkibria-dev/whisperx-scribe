# Plan: User Documentation by Audience (Diátaxis)

| | |
|---|---|
| **Status** | **Implemented** 2026-09-17 (see §7 for what was verified) |
| **Date** | 2026-09-17 |
| **Scope** | Markdown documentation: new files under `docs/`, the three READMEs, `README-testing.md`, `CLAUDE.md`. One new test: `tests/test-docs.ps1` (documentation coverage check). |
| **Explicitly out of scope** | Any change to script behavior, parameters, defaults or `settings.json`. Documentation describes the code as it is. Making `test-pipeline.ps1` read `settings.json` is deferred to a separate session (§8). |

This plan covers everything needed to do the work. It records the current gaps, the target
structure, the decisions and why they were made, the steps in order, and how to check the result.

---

## 1. Current state — the problem

The documentation is four Markdown files: `README.md`, `01-Environment-Setup/README.md`,
`02-Transcription-Pipeline/README.md` and `README-testing.md`. Each one mixes getting-started
steps, reference facts and background explanation. Nearly all of it is written for one reader:
someone running the default command.

### 1.1 Undocumented options

An audit of every script's parameter block and every `argparse` definition found **33 user-facing
options**. Only **7** are documented in a user doc, and 3 of those appear only in the settings table.

| Entry point | Options | Documented |
|---|---|---|
| `02-Transcription-Pipeline/run_pipeline.ps1` | `-Audio`, `-Model`, `-Language`, `-Device`, `-ComputeType`, `-MinSpeakers`, `-MaxSpeakers`, `-OutputDirectory`, `-HFToken` | `-OutputDirectory` only. `-Audio` appears only in examples. |
| `01-Environment-Setup/setup.ps1` | `-PythonCommand`, `-EnvironmentPath`, `-RequirementsFile`, `-SkipHuggingFaceToken`, `-HFToken` | `-EnvironmentPath`, `-HFToken` |
| `01-Environment-Setup/02-create-environment.ps1` | `-PythonCommand`, `-EnvironmentPath` | None |
| `01-Environment-Setup/03-install-whisperx.ps1` | `-UpgradePip`, `-EnvironmentPath` | None |
| `01-Environment-Setup/04-verify-installation.ps1` | `-EnvironmentPath` | None |
| `tests/test-clean-install.ps1` | `-PythonCommand`, `-KeepTemp` | Both |
| `tests/test-pipeline.ps1` | `-Audio`, `-OutputDirectory`, `-Model`, `-Device`, `-ComputeType`, `-Language`, `-KeepOutput` | `-Audio`, `-KeepOutput` |
| `scripts/transcribe.py` | `audio`, `--model`, `--language`, `--device`, `--compute-type`, `--output` | None |
| `scripts/align_and_merge.py` | `audio`, `raw_json`, `--device`, `--output` | None |
| `scripts/diarize.py` | `audio`, `aligned_json`, `--device`, `--hf-token`, `--min-speakers`, `--max-speakers`, `--output` | None |
| `scripts/finalize.py` | `diarized_json`, `--output` | None |

### 1.2 Other gaps

- **Allowed values are never listed.** Nothing says which models, devices, compute types or
  language codes are valid.
- **Precedence is not in any user doc.** The order is built-in defaults, then `settings.json`,
  then `settings.local.json`, then the command-line argument. It appears only in `CLAUDE.md`.
- **The `HF_TOKEN` variable is never named.** The docs don't explain how the token is looked up
  (argument, then `HF_TOKEN`, then an interactive prompt), or that `setup.ps1` saves it at user level.
- **`settings.local.json` has only one example,** for `environment.venvPath`. There is none for
  pipeline defaults such as `pipeline.language`.
- **`tests/test-pipeline.ps1` doesn't read `settings.json`.** It hard-codes `medium` / `cpu` /
  `int8` as its own defaults, and the docs don't say so.
- **Many common tasks have no instructions.** Examples: setting the language, using a GPU,
  choosing a faster or more accurate model, and debugging one stage.

## 2. Audiences

| Audience | Situation | What they need | Diátaxis type |
|---|---|---|---|
| **First-time user** | Not a developer, has a recording, has never run the project | One complete, guaranteed path from a fresh clone to a finished transcript | Tutorial |
| **Regular user** | Has a working setup and a specific goal | Short numbered steps for that goal, no background | How-to guide |
| **Maintainer / troubleshooter** | Debugging a stage, a setup failure or a test | Exact parameters, defaults, allowed values, file formats | Reference |
| **Evaluator / decision-maker** | Choosing settings, or wanting to understand the design | Why it works this way, and the trade-offs | Explanation |

Contributors who run the tests are served by the maintainer and regular-user documents. They
don't get a separate set.

## 3. Target state

```text
README.md                              short overview and entry point; links by audience
01-Environment-Setup/README.md         short; links to the setup tutorial, how-tos, reference
02-Transcription-Pipeline/README.md    short; stage diagram; links to reference and how-tos
README-testing.md                      short; links to the testing how-to and reference

docs/
├── tutorials/
│   └── first-transcription.md         fresh clone → setup → transcribe the bundled sample → read the result
├── how-to/
│   ├── set-transcription-language.md
│   ├── choose-model-and-speed.md      model, device, compute type (CPU vs GPU)
│   ├── set-speaker-count.md
│   ├── choose-output-location.md
│   ├── configure-hugging-face-token.md
│   ├── change-machine-defaults.md     writing settings.local.json
│   ├── move-the-python-environment.md
│   ├── run-a-single-stage.md          debugging with the Python scripts directly
│   ├── repair-an-environment.md       using the numbered 01–04 maintenance scripts
│   └── run-the-tests.md
├── reference/
│   ├── run-pipeline.md                every run_pipeline.ps1 parameter
│   ├── setup-scripts.md               setup.ps1 and 01–04 scripts
│   ├── pipeline-stage-scripts.md      the four Python CLIs
│   ├── test-scripts.md                the four tests and their parameters
│   ├── settings.md                    every settings.json key, and the precedence order
│   ├── environment-variables.md       HF_TOKEN, LOCALAPPDATA and other variables the configuration expands
│   └── output-files.md                the four outputs, naming, and each JSON schema contract
├── explanation/
│   ├── how-the-pipeline-works.md      four stages, file passing, why intermediate files are kept
│   ├── configuration-layering.md      why defaults → settings.json → local → argument
│   ├── runtime-outside-the-repository.md
│   └── accuracy-and-speed-trade-offs.md   model size, device, compute type, language detection
└── plans/                             unchanged
```

Every reference entry for a parameter has the same fields: **name, type, default, where the
default comes from, allowed values, what it does, example**.

### 3.1 Required heading format in reference docs

The coverage test (D9) reads headings, so the reference docs must use this exact heading structure:

- Each script gets a level-2 heading with its file name in a code span:
  ``## `run_pipeline.ps1` ``. Every script listed in §1.1 gets one, and so do
  `01-check-prerequisites.ps1`, `test-settings.ps1` and `test-docs.ps1`, which take no parameters.
- Each parameter gets a level-3 heading under its script, spelled exactly as on the command line:
  ``### `-Model` ``, ``### `--compute-type` ``, ``### `audio` `` (positional).
- Each setting in `docs/reference/settings.md` gets a level-3 heading with its dotted key:
  ``### `pipeline.language` ``.

| Reference file | Scripts or settings it must cover |
|---|---|
| `run-pipeline.md` | `02-Transcription-Pipeline/run_pipeline.ps1` |
| `setup-scripts.md` | `01-Environment-Setup/*.ps1` |
| `pipeline-stage-scripts.md` | `02-Transcription-Pipeline/scripts/*.py` |
| `test-scripts.md` | `tests/*.ps1` |
| `settings.md` | every key returned by `Get-DefaultProjectSettings` in `settings.ps1` |

## 4. Decisions and rationale

| # | Decision | Rationale |
|---|---|---|
| D1 | Put Diátaxis documents in type subfolders under `docs/` (`tutorials/`, `how-to/`, `reference/`, `explanation/`) | Follows the global preference (docs-as-code, Diátaxis, one type per file). `CLAUDE.md` already reserves `docs/` for these types. Subfolders keep the four types visibly separate and leave `docs/plans/` alone. |
| D2 | Keep the READMEs, but cut them down to entry points | Readers find READMEs first, on GitHub and in the directory tree. Each README says what its directory is for, gives the single most common command, and links to the docs for each audience. The detail moves to `docs/`. |
| D3 | Write documents in this order: reference, how-to, tutorial, explanation | The missing options are the concrete defect. Everything else links to the reference, so it comes first. How-tos cover most day-to-day needs. The tutorial and explanation docs depend on both. |
| D4 | Take every fact from the source code, not from memory or upstream docs | Defaults and allowed values must match this repository's code and pinned `whisperx==3.8.6`. Model names come from the installed faster-whisper. Compute types come from CTranslate2. Language codes come from `whisperx.utils.LANGUAGES`, together with the alignment-model tables in `whisperx/alignment.py`. |
| D5 | Document how the code behaves today, including its quirks | This plan changes no behavior. Quirks such as `test-pipeline.ps1` ignoring `settings.json` are documented as they are and listed in §7 as possible follow-ups. |
| D6 | The tutorial uses `tests/data/sample-2-speakers.wav` | It is already in the repo and has a known two-speaker result, so every reader's first run succeeds the same way. |
| D7 | The numbered 01–04 setup scripts get a reference entry and a repair how-to | The READMEs already tell users not to run them in normal use. Maintainers still need their parameters. |
| D8 | Update the `CLAUDE.md` "Conventions" bullet about docs | It currently says docs live next to what they describe. It must describe the new layout, so future changes add docs to the right place. |
| D9 | Enforce coverage with a new test, `tests/test-docs.ps1`, instead of a one-off check | Without a test, the next new parameter goes undocumented again. The test checks in both directions: every option in the code has a reference heading (nothing missing), and every reference heading exists in the code (nothing stale after a rename or removal). |
| D10 | Make it a separate fourth test, not new assertions in `test-settings.ps1` | `test-settings.ps1` has one clear purpose, settings layering and git hygiene. A separate test keeps that purpose clear, and a failure message points straight at the docs. |
| D11 | Read the code statically: PowerShell AST for `.ps1` parameter blocks, a regex over `add_argument(` for the Python scripts, and `Get-DefaultProjectSettings` for setting keys | Like `test-settings.ps1`, it needs no venv, no network and no WhisperX, and finishes in seconds. Running `script.py --help` instead would import `whisperx` and need the environment. Reading the real scripts and the real settings loader follows the project rule of testing real entry points, not a copied list. |

## 5. Implementation steps

Each step ends with the documents it creates or changes being internally consistent.

1. **Gather facts.** For every entry point in §1.1, read the parameter block or `argparse`
   definition and record the name, type and default.
   - Record where the default comes from: `settings.ps1` `Get-DefaultProjectSettings` or a
     hard-coded value.
   - Look up the allowed values in the installed venv (D4).
   - Record the token lookup order from `diarize.py` and `run_pipeline.ps1`.
   - Record the output JSON keys each stage reads and writes.
2. **Coverage test first.** Write `tests/test-docs.ps1`, following the conventions of `test-settings.ps1`:
   - Use `$ErrorActionPreference = "Stop"`, derive paths from `$PSScriptRoot`, print a pass/fail
     summary, and exit non-zero on failure.
   - **Discovery:** find every `.ps1` under `01-Environment-Setup/`, `02-Transcription-Pipeline/`
     and `tests/`, and every `.py` under `02-Transcription-Pipeline/scripts/`. Globbing (not a
     fixed list) means new scripts are checked automatically.
   - **Code side:** read `ParamBlock.Parameters` from each PowerShell AST; for Python, collect the
     first string literal of each `add_argument(` call (multi-line aware). Read setting keys by
     dot-sourcing `settings.ps1` and walking `Get-DefaultProjectSettings`.
   - **Docs side:** use the file mapping in §3.1 to parse the `##` / `###` headings of each reference file.
   - **Assert:**
     - every script has a `##` section;
     - every parameter has a `###` heading in its script's section;
     - every `###` heading in a script section matches a real parameter;
     - every `##` section names a script that exists;
     - every setting key has a heading in `settings.md`, and no heading names a key that doesn't exist.
   - Each failure names the script or setting, the option, and the reference file to edit.
   - Run it now and confirm it fails. That is the §1.1 gap, now enforced.
3. **Reference docs.** Write the seven files in `docs/reference/`, using the field layout in §3
   and the heading format in §3.1. Repeat until `tests/test-docs.ps1` passes. Include the test
   itself in `test-scripts.md`.
4. **How-to guides.** Write the ten files in `docs/how-to/`. Each has a one-line goal,
   prerequisites, numbered steps, and a link to the matching reference entry. None explains why.
   `run-the-tests.md` covers all four tests.
5. **Tutorial.** Write `docs/tutorials/first-transcription.md`. Test it by following it
   literally on this machine.
6. **Explanation docs.** Write the four files in `docs/explanation/`. They contain no steps or
   commands beyond short illustrations.
7. **Cut the READMEs down.** Move detail out of `README.md`, both phase READMEs and
   `README-testing.md` into the new docs. Replace it with links grouped by audience ("New here?",
   "Doing a specific task", "Looking up an option", "Understanding the design"). Nothing is
   deleted without first being moved. `README-testing.md` lists four tests.
8. **Update `CLAUDE.md`.**
   - Change the documentation convention (D8).
   - Change "there are exactly three" tests to four, and add `.\tests\test-docs.ps1` to Commands.
   - Add a rule: after adding, renaming or removing a parameter or setting, update
     `docs/reference/` and run `test-docs.ps1`.
9. **Update this plan's status** to implemented and record what was verified.

## 6. Validation criteria

1. **Every option is covered.** `.\tests\test-docs.ps1` passes, in seconds, with no venv.
   Before the reference docs existed it failed, listing the §1.1 gaps.
   - **The test catches real problems.** Temporarily add a dummy parameter to a script: the test
     fails and names it. Temporarily add a `###` heading for a parameter that doesn't exist: the
     test fails and names it. Revert both.
2. **Defaults match the code.** Every default in the reference docs matches the parameter
   block, `argparse`, or `Get-DefaultProjectSettings` in `settings.ps1`.
3. **One type per file.** Tutorials and how-tos contain no rationale paragraphs. Explanations
   contain no numbered steps. Reference docs contain no instructions or opinions.
4. **The tutorial works.** Following the tutorial exactly produces `sample-2-speakers_final.txt`
   with `SPEAKER_00` and `SPEAKER_01`.
5. **Commands work.** Every command in the how-tos runs as written. For slow pipeline commands,
   the parameter binding is checked with the sample file. `-Language xx`-style failures are not
   documented as success.
6. **Links resolve.** Every relative Markdown link points to an existing file and heading.
7. **Nothing is lost.** Every fact in the old READMEs is either still in a README or present in
   a `docs/` file.
8. **The repo is still healthy.** `.\tests\test-settings.ps1` still passes. `git status` shows
   only Markdown changes plus the new `tests/test-docs.ps1`.

## 7. Verification results (2026-09-17)

| Criterion | Result |
|---|---|
| 1. Every option covered | **Pass** — `tests\test-docs.ps1`, 15 assertions, seconds, no venv. Before the reference docs existed it failed with 20 assertions, listing all 33 options and 13 settings. |
| 1a. The test catches real problems | **Pass** — a dummy `-DummyProbe` parameter added to `04-verify-installation.ps1` failed as `Undocumented option`; a `### \`--stale-probe\`` heading under `finalize.py` failed as `Documented option not in the script`. Both reverted. |
| 2. Defaults match the code | **Pass** — checked against each `param()` block, each `argparse` default, and `Get-DefaultProjectSettings`. Allowed values were read from the installed venv: faster-whisper 1.2.1 model list, `ctranslate2.get_supported_compute_types("cpu")` (CTranslate2 4.8.2), `whisperx.utils.LANGUAGES` (100) and the 41 codes in the `DEFAULT_ALIGN_MODELS_*` tables. |
| 3. One type per file | **Pass** — by review. |
| 4. The tutorial works | **Not verified.** See the defect below. Steps 1–4 and 6 run; the transcript content in step 5 could not be reproduced on this machine. |
| 5. Commands work | **Pass** for the cheap ones, run as written: `Get-ProjectSettings ... .pipeline`, `[bool]$env:HF_TOKEN`, `finalize.py` on a real `_diarized.json`, `ctranslate2.get_supported_compute_types`. `transcribe.py --language english` failed exactly as documented, with `'english' is not a valid language code`. |
| 6. Links resolve | **Pass** — all relative links and anchors across the 30 Markdown files, checked with a script. |
| 7. Nothing lost | **Pass** — every removed README line was checked against the new docs. Two facts had been dropped and were added to `docs/reference/test-scripts.md`: the skipped assertions when `settings.local.json` is absent, and FFmpeg not needing to be on `PATH` for the clean-install test. |
| 8. Repository healthy | **Pass** — `test-settings.ps1`, 48 assertions. `git status` shows only Markdown changes plus `tests/test-docs.ps1`. |

### Pre-existing defect found while verifying, not fixed here

`tests\test-pipeline.ps1` **fails on this machine**, for reasons unrelated to this documentation
work:

```text
Diarization validation failed. Expected at least 2 speakers, found: SPEAKER_00.
```

Stage 1 transcribes the whole 19-second sample as a single segment reading `Oh Oh Oh`, with
`avg_logprob` -1.70, so there is almost nothing for diarization to attribute. Checked and ruled
out: the audio decodes correctly (`whisperx.load_audio` matches the raw WAV samples exactly,
correlation 1.0), and the run used `-Language en`, so detection was not the cause.

Also observed on this machine, and possibly related:

- TorchCodec cannot load its DLLs, because the installed FFmpeg is 9.0.1 while TorchCodec 0.7
  looks for FFmpeg 4–7. WhisperX falls back to another decoder and the audio is correct.
- `huggingface.co` cannot be reached: `SSL: CERTIFICATE_VERIFY_FAILED`. The runs above needed
  `HF_HUB_OFFLINE=1` and the already-cached models.
- A comparison run at `-ComputeType float32`, to see whether `int8` quantization explained the
  poor transcript, could not complete: `medium` at `float32` fails at model load with
  `RuntimeError: mkl_malloc: failed to allocate memory` on this machine. So quantization is
  neither confirmed nor ruled out as the cause. That memory limit is now documented in
  `docs/reference/run-pipeline.md` and `docs/explanation/accuracy-and-speed-trade-offs.md`.

## 8. Follow-ups outside this plan

- **Separate session (decided 2026-09-17):** make `test-pipeline.ps1` read pipeline defaults
  from `settings.json` instead of hard-coding `medium` / `cpu` / `int8`.
  - Until then, `docs/reference/test-scripts.md` documents the current hard-coded defaults.
  - That work must update the reference doc too. `test-docs.ps1` checks parameter names, not
    default values, so it won't catch a stale default.
- **No action decided:** a bad language code isn't caught until after transcription, when
  `align_and_merge.py` fails. The reference docs and the language how-to state this.
