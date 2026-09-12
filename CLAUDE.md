# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Windows/PowerShell audio transcription project built on WhisperX. An audio file goes in, a
time-aligned, speaker-labeled transcript comes out. Two phases, each a numbered directory:
`01-Environment-Setup` (one-time, per machine) and `02-Transcription-Pipeline` (the actual work).

## Commands

All commands run from the repository root.

```powershell
# One-time environment setup (creates .venv, installs deps, checks FFmpeg, configures HF_TOKEN)
.\01-Environment-Setup\setup.ps1
.\01-Environment-Setup\setup.ps1 -HFToken "hf_..."      # non-interactive token
.\01-Environment-Setup\setup.ps1 -SkipHuggingFaceToken  # skip the token step

# Run the pipeline
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
.\02-Transcription-Pipeline\run_pipeline.ps1 "audio.wav" -Model medium -Device cpu -ComputeType int8 `
    -Language en -MinSpeakers 2 -MaxSpeakers 2 -OutputDirectory ".\out"

# Tests (there are exactly two; both are PowerShell scripts, not pytest)
.\tests\test-clean-install.ps1          # fresh-clone setup test in a temp repo copy
.\tests\test-clean-install.ps1 -KeepTemp
.\tests\test-pipeline.ps1               # end-to-end run against tests\data\sample-2-speakers.wav
.\tests\test-pipeline.ps1 -KeepOutput

# Run one pipeline stage directly (debugging; normally use run_pipeline.ps1)
.\.venv\Scripts\python.exe .\02-Transcription-Pipeline\scripts\transcribe.py audio.wav --output audio_raw.json
```

There is no linter, formatter, or test framework configured. `test-pipeline.ps1` is the
smallest meaningful check after touching pipeline code; it runs the real
`run_pipeline.ps1`, so on CPU it takes minutes and downloads models on first run.

## Architecture

**Four stages, file-passing, no shared Python module.** Each `scripts/*.py` is a standalone
argparse CLI that reads its input from disk and writes its output to disk. They never import
each other. `run_pipeline.ps1` is the only orchestrator: it resolves paths, derives all four
output names from the audio file stem, and invokes each script in turn via the venv's
`python.exe`, aborting on the first non-zero exit code.

```
audio.wav → transcribe.py      → <stem>_raw.json       (segments + detected language)
          → align_and_merge.py → <stem>_aligned.json   (word-level timings; reads `language` from _raw)
          → diarize.py         → <stem>_diarized.json  (SPEAKER_NN on words/segments; needs HF_TOKEN)
          → finalize.py        → <stem>_final.txt      (human-readable, timestamped speaker turns)
```

Outputs land beside the input audio unless `-OutputDirectory` is given. The intermediate JSON
is kept deliberately — it is the debugging surface when a stage misbehaves.

Consequences worth knowing before changing things:
- A stage's output schema is the next stage's input contract. `align_and_merge.py` requires
  `language` in `_raw.json`; `finalize.py` requires per-word `speaker` keys in `_diarized.json`
  (it groups words into turns by speaker change, then merges adjacent same-speaker turns).
- Each script re-loads the audio with `whisperx.load_audio`. That is intentional process
  isolation, not an oversight; don't "optimize" it into one long-running process without
  discussing it.
- Every script's `--output` defaults are derived from the input filename suffix, so renaming
  the `_raw` / `_aligned` / `_diarized` conventions touches several files.

**Environment discovery.** `run_pipeline.ps1` looks for `Scripts\python.exe` under `.venv`,
then `env`, then `whisperx-env` at the repo root. Nothing activates the venv; the interpreter
is invoked by absolute path. `.venv` is never committed — each machine builds its own.

**Hugging Face token.** Diarization needs it. Resolution order in `diarize.py`: `--hf-token`,
then `HF_TOKEN` env var, then an interactive `getpass` prompt (skipped when stdin is not a
tty, in which case it errors out). `run_pipeline.ps1` resolves the token *before* the slow
stages and passes it to children through `HF_TOKEN`, clearing it afterwards if it prompted.
`setup.ps1` persists it to the user-level `HF_TOKEN` environment variable. Never log, echo,
or commit the token.

**Dependency pinning.** `requirements.txt` pins `whisperx==3.8.6` and `torchcodec==0.7.0`
(the TorchCodec generation matching the PyTorch 2.8.x that WhisperX pulls in). The
maintenance script `03-install-whisperx.ps1` additionally pins `torch/torchaudio/torchvision`
2.8.0 from the PyTorch CPU index for a predictable Windows CPU baseline — `setup.ps1` does
not do this and lets pip resolve. Keep those two paths in mind when a version bump breaks one
but not the other. FFmpeg 8+ can break TorchCodec loading; 7.x shared builds are the safe choice.

## Setup scripts

`setup.ps1` is the public entry point and is self-contained — it does not call the numbered
scripts. `01-check-prerequisites.ps1` … `04-verify-installation.ps1` are maintenance and
troubleshooting building blocks that overlap with it. Fixing a setup bug usually means
touching `setup.ps1`; check whether the numbered script covering the same ground needs the
same fix.

FFmpeg handling in `setup.ps1` deliberately ignores winget's exit code (winget returns
non-zero for "already installed"). The real test is whether `ffmpeg.exe` can be located and
executed afterwards, searched across PATH, the WinGet package cache, and common Windows
install roots.

## Conventions

- Python: `from __future__ import annotations`, `pathlib.Path` throughout, `main() -> int`
  returning an exit code via `raise SystemExit(main())`, errors printed to stderr prefixed
  `ERROR:`, progress printed to stdout.
- PowerShell: `$ErrorActionPreference = "Stop"`, paths derived from `$PSScriptRoot` (never
  absolute or user-specific), `-LiteralPath` on filesystem tests, `throw` with a multi-line
  here-string that tells the user what to do next.
- Tests call the real production entry points rather than reimplementing them — that is the
  stated test philosophy. Keep it when adding tests.
- Docs live in Markdown next to what they describe: root `README.md`, one `README.md` per
  phase directory, `README-testing.md` for tests.
