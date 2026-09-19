# Progress reporting for the transcription pipeline

**Status:** Implemented. All six planned files were changed on
`feature/pipeline-progress-reporting`. `tests/test-settings.ps1` and `tests/test-docs.ps1`
both pass. `tests/test-pipeline.ps1` currently fails on this machine for an unrelated
reason — the venv's Python cannot complete a TLS handshake with `huggingface.co`
(`SSLCertVerificationError: unable to get local issuer certificate`), reproduced even with
a bare `requests.get()` outside of any pipeline code, so it predates this change. Verified
the actual feature instead by running `run_pipeline.ps1` directly against
`tests/data/sample-2-speakers.wav` with `HF_HUB_OFFLINE=1` (all three models were already
cached locally): real `Transcribe:`/`Align:`/`Diarize:` percentage lines appeared with
correct elapsed/ETA formatting, `Diarize:` correctly tagged `[segmentation]`/`[embeddings]`,
and `run_pipeline.ps1` printed a `--- <script>.py completed in <duration> ---` line after
every stage plus a final `Total time: <duration>` line. The SSL issue in the venv is a
separate, pre-existing environment problem and was not fixed as part of this change.

## Context

Running `run_pipeline.ps1` on a real recording produced long silent stretches with no
indication of what was happening or how much longer it would take. A captured log
(`whisper-log.txt`) shows transcription starting at 16:23:41 and the next visible
timestamp — diarization starting — at 18:08:46: roughly 1h45m during which transcribe
and align together printed nothing but their fixed "stage started" lines. Diarization
itself (the slowest stage on long audio) then runs with zero output until it finishes.
The user wants the pipeline to report percentage/ETA/elapsed progress so it's clear the
process is alive and roughly how much longer it will take.

Investigation (via the pinned `whisperx==3.8.6` wheel) found that WhisperX already
exposes a `progress_callback: Callable[[float], None]` parameter on all three
whisperx-backed operations used by this pipeline — `model.transcribe()`,
`whisperx.align()`, and `DiarizationPipeline.__call__()` — each invoking it with a real,
monotonically increasing 0–100 percentage as work proceeds. None of the three pipeline
scripts currently pass this parameter. This means real percentage + ETA is achievable
for every slow stage without any heartbeat fallback or new dependency.

Confirmed via user Q&A:
- All four stages should give some feedback, not just the slowest one.
- Real percentage/ETA is preferred over a plain heartbeat, wherever the library supports it.
- Output must be new stdout lines (not carriage-return/in-place bars), since it must
  stay readable when the user redirects the whole run to a log file, as they already do.
- No new CLI flag or settings.json key — progress reporting is always-on with hardcoded
  thresholds; nothing here needs to be user-tunable, and every new flag/setting must be
  documented and kept in sync (`tests/test-docs.ps1` enforces this by name), so skipping
  it keeps the change small.

## Design

**Per-stage progress lines (transcribe, align, diarize).** Each script gets an identical,
small, self-contained progress-printer helper (duplicated per file, not factored into a
shared module — this repo's architecture is deliberately "no shared Python module,
scripts never import each other," per `CLAUDE.md`). The helper wraps a `progress_callback`
closure that:

- Formats elapsed time (since the stage's own call started) and a linear ETA
  (`elapsed * (100 - pct) / pct`) using a compact duration format: `45s`, `12m34s`, `1h05m12s`.
- Throttles printing so a stage with hundreds of tiny segments doesn't spam the console:
  print only if `is_first OR is_last(pct>=100) OR (pct advanced >=5) OR (>=15s since last print)`.
  OR (not AND) is deliberate — with AND, slow-but-steady progress under both thresholds
  could still go silent indefinitely, which is the exact bug being fixed. The first and
  last callbacks always print unconditionally, so even a short test file with only 1-2
  total callbacks still shows at least a start and a 100% line.
- Prints via `print(..., flush=True)` — explicit flush matters here specifically because
  the failure mode being fixed is invisible progress when stdout is redirected to a file
  (as the user already does to capture logs), and Python fully buffers stdout in that case.

Format: `"<Stage>: <PCT>% (elapsed <elapsed>, ETA <eta>)"`, e.g.:
```
Transcribe: 34% (elapsed 12m34s, ETA 24m18s)
Transcribe: 100% (elapsed 45m02s, ETA 0s)
Align: 58% (elapsed 3m02s, ETA 2m11s)
```

**Diarize gets a phase tag.** `DiarizationPipeline`'s bridge to pyannote's internal hook
uses a fixed, documented weighting (`segmentation: 0–50%`, `embeddings: 50–99%`) before
collapsing it to the single 0–100 float our callback receives — so the phase is exactly
recoverable from the percentage itself (not a guess): `" [segmentation]"` if `pct < 50`
else `" [embeddings]"`. This avoids reimplementing pyannote's native hook signature just
to get phase names, while still directly addressing the biggest pain point (diarize was
the longest silent stretch in the real log):
```
Diarize: 27% [segmentation] (elapsed 1m40s, ETA 4m30s)
Diarize: 76% [embeddings] (elapsed 6m12s, ETA 1m57s)
```

**Per-stage and total duration at the orchestrator level.** `finalize.py` is fast (pure
stdlib, no percentage progress needed), so "all four stages give feedback" is satisfied
instead in `run_pipeline.ps1`: `Invoke-PythonScript` records each stage's start/end time
and prints a completion-with-duration line after every stage (including `finalize.py`),
and the final summary block prints total pipeline duration.

Constants (`min pct delta = 5.0`, `min interval = 15.0s`) are hardcoded module-level
constants in each Python file — no new CLI flag or settings key, per the decision above.

## Implementation

### `02-Transcription-Pipeline/scripts/transcribe.py`

- Add `import time` and `from typing import Callable` to the imports.
- Insert between the imports and `def main() -> int:` a self-contained block: two
  module-level constants (`_PROGRESS_MIN_PCT_DELTA = 5.0`, `_PROGRESS_MIN_INTERVAL_SECS = 15.0`),
  a `_fmt_duration(seconds: float) -> str` formatter, and a
  `_make_progress_printer(label: str) -> Callable[[float], None]` closure factory
  implementing the throttle logic described above, printing with `flush=True`.
- At the call site (currently line 75), build the callback and pass it through:
  ```python
  progress_cb = _make_progress_printer("Transcribe")
  result = model.transcribe(audio, language=args.language, progress_callback=progress_cb)
  ```
  Do not pass `print_progress=True` — that triggers WhisperX's own stdout progress
  printing, which is redundant with ours and not throttled the same way.

### `02-Transcription-Pipeline/scripts/align_and_merge.py`

- Same imports, and a byte-identical copy of the constants/`_fmt_duration`/
  `_make_progress_printer` block from `transcribe.py`.
- At the call site (currently lines 103-110):
  ```python
  progress_cb = _make_progress_printer("Align")
  aligned = whisperx.align(
      result["segments"], model_a, metadata, audio, args.device,
      return_char_alignments=False, progress_callback=progress_cb,
  )
  ```

### `02-Transcription-Pipeline/scripts/diarize.py`

- Same imports, and a copy of the helper block with the phase-tag line added inside
  `_progress_callback` (`phase = " [segmentation]" if pct < 50.0 else " [embeddings]"`,
  included in the printed line).
- Widen the kwargs dict's type at line 178 to hold the callback too (safe at runtime
  because `from __future__ import annotations` is already active):
  ```python
  diarization_kwargs: dict[str, int | Callable[[float], None]] = {}
  ```
- After the existing min/max-speakers population (lines 180-184), add:
  ```python
  diarization_kwargs["progress_callback"] = _make_progress_printer("Diarize")
  ```
  The existing call at line 187-190 (`diarize_model(audio, **diarization_kwargs)`) needs
  no change — the callback flows through automatically.

### `02-Transcription-Pipeline/run_pipeline.ps1`

- Right after `$ErrorActionPreference = "Stop"`, capture `$PipelineStart = Get-Date` and
  add a `Format-Duration` helper function (mirrors the Python formatter's output style —
  `1h05m12s` / `12m34s` / `45s` — so lines from both languages read consistently in the
  same log).
- In `Invoke-PythonScript` (lines 127-147), capture `$StageStart = Get-Date` right before
  invoking the script, and after the existing exit-code check, print a completion line:
  ```powershell
  $StageElapsed = Format-Duration ((Get-Date) - $StageStart)
  Write-Host "--- $ScriptName completed in $StageElapsed ---" -ForegroundColor Cyan
  ```
  This applies uniformly to all four stages, including `finalize.py`, with no changes
  needed to `finalize.py` itself.
- In the final summary block (currently lines 212-217), add a total-duration line right
  after `=== Pipeline complete ===` and before the existing output-path lines:
  ```powershell
  Write-Host "Total time: $(Format-Duration ((Get-Date) - $PipelineStart))" -ForegroundColor Green
  ```

### Documentation (same change, per `CLAUDE.md`'s docs-as-code rule)

No new CLI flags or settings keys are being added, so `test-docs.ps1`'s name-matching
check needs no new entries — but the console-output reference docs describe literal
output text, so they still need updating to stay accurate:

- `docs/reference/pipeline-stage-scripts.md`: replace the `## Common behavior` table's
  `| Progress | Written to stdout |` row with a description of the new format, throttling
  rule (1 line per 5 percentage points or 15 seconds, always printing the first and 100%
  updates), which three scripts do it, and diarize's phase tag; note `finalize.py` prints
  no percentage progress.
- `docs/reference/run-pipeline.md`: add two rows to the `## Console output` table:
  one for `--- <script>.py completed in <duration> ---` (printed after each stage), one
  for `Total time: <duration>` (printed in the final summary).

## Verification

1. Run `tests/test-pipeline.ps1` against the existing short sample
   (`tests/data/sample-2-speakers.wav`) and inspect output for: at least one non-100% and
   exactly one 100% line per stage for `Transcribe:`/`Align:`/`Diarize:` (the
   first/last-always rule guarantees this even with very few total callbacks on a short
   file), `Diarize:` lines showing phase tags, and four
   `--- <script>.py completed in ... ---` lines plus one final `Total time: ...` line.
2. Run `tests/test-docs.ps1` to confirm no flag/setting-name drift was introduced (should
   pass unchanged, since no new flags or settings keys are added).
3. Spot-check the throttle logic isn't spammy or silent using a quick scratch script that
   drives `_make_progress_printer` with a synthetic sequence of increasing percentages and
   a monkeypatched `time.monotonic`, confirming: bounded total line count, first and last
   calls always print, and no gap exceeds both thresholds at once.
4. Diff the two updated doc tables against the actual strings observed in step 1 so the
   reference docs stay literal, matching the existing convention in `run-pipeline.md`.

### Files touched
- `02-Transcription-Pipeline/scripts/transcribe.py`
- `02-Transcription-Pipeline/scripts/align_and_merge.py`
- `02-Transcription-Pipeline/scripts/diarize.py`
- `02-Transcription-Pipeline/run_pipeline.ps1`
- `docs/reference/pipeline-stage-scripts.md`
- `docs/reference/run-pipeline.md`
