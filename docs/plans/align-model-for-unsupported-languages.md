# Plan: alignment model for languages without a WhisperX default

**Status:** Implemented 2026-09-17. Verified: `test-settings.ps1` passed (60 assertions),
`test-docs.ps1` passed (15 assertions), and the negative stage-2 check on the real Bengali
`_raw.json` printed the `ERROR:` without a traceback and exited 1. The user then loaded
`arijitx/wav2vec2-xls-r-300m-bengali` with `whisperx.load_align_model('bn', 'cpu', model_name=...)`
on their machine, and it succeeded. Not yet verified: an end-to-end Bengali run, and
`test-pipeline.ps1`.

## Current state and problem

A Bengali phone recording failed in stage 2:

```
ValueError: No default align-model for language: bn
```

- Stage 1 (`transcribe.py`) succeeded. It detected `bn` at 0.30 confidence and wrote 28 segments.
- `align_and_merge.py` called `whisperx.load_align_model(language_code, device)` with no model
  name. WhisperX 3.8.6 only knows defaults for 41 languages (`DEFAULT_ALIGN_MODELS_TORCH` and
  `DEFAULT_ALIGN_MODELS_HF` in `whisperx/alignment.py`). `hi`, `ur`, `te` and `ml` are on that
  list, but `bn` is not. `load_align_model` already accepts `model_name=`, but the pipeline had
  no way to pass one.
- Alignment cannot simply be skipped. `diarize.py` assigns speakers per word, and `finalize.py`
  builds turns only from words that carry a `speaker` key. Without alignment, `_final.txt` would
  be empty.
- The `torchcodec is not installed correctly` warning in the same log did not cause the failure.
  Every stage decodes audio with `whisperx.load_audio` (an FFmpeg subprocess) and hands pyannote
  an in-memory waveform. That is the path the warning names as a workaround.

## Target state

- `align_and_merge.py --align-model <name>`, `run_pipeline.ps1 -AlignModel <name>`, and the
  setting `pipeline.alignModel` (default `""`). They layer as usual: defaults → settings.json →
  settings.local.json → argument.
- When the model cannot be loaded, stage 2 prints an `ERROR:` with the WhisperX reason and what
  to do next, then exits 1. There is no traceback.

## Decisions

- **One model name, not a language→model map.** A recording has one language, so a single
  explicit value is enough. This matches the project's "explicit configuration, no discovery"
  style. A map can be added later if needed.
- **No fallback that skips alignment.** Downstream stages need word timings. Stopping at stage 2
  with guidance is better than producing an empty transcript.
- **Catch `ValueError` and include its message.** WhisperX raises `ValueError` both for "no
  default model" and for "named model could not be loaded". The second case includes network
  failures, so the original message is printed rather than hidden.
- **Example model:** `arijitx/wav2vec2-xls-r-300m-bengali` (XLS-R 300M fine-tuned on Bengali,
  CTC, character vocabulary). It is used as the documented example and is not pinned in
  `settings.json`.

## Implementation steps

1. Add `--align-model` to `align_and_merge.py` and pass it as `model_name=`. Wrap the load in
   `try/except ValueError`.
2. Add `pipeline.alignModel` to `settings.json` and `Get-DefaultProjectSettings` in `settings.ps1`.
3. Add `-AlignModel` to `run_pipeline.ps1`. Fall back to the setting, and append `--align-model`
   only when the value is not empty.
4. Document it in `docs/reference/run-pipeline.md`, `pipeline-stage-scripts.md` and
   `settings.md`, and add `docs/how-to/transcribe-unsupported-language.md`.

## Validation

- `.\tests\test-settings.ps1` passes.
- `.\tests\test-docs.ps1` passes.
- `align_and_merge.py` on a `bn` `_raw.json` without `--align-model` prints the `ERROR:` and
  exits 1, with no traceback.
- `run_pipeline.ps1 <bengali audio> -Language bn -AlignModel arijitx/wav2vec2-xls-r-300m-bengali`
  produces a non-empty `_final.txt` with speaker turns. **Pending.**
- `.\tests\test-pipeline.ps1` (English, no align model) still passes. **Pending.**
