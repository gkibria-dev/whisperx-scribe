"""Align a WhisperX transcription to word-level timestamps.

Stage 2 of the pipeline. Creates <stem>_aligned.json.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Callable

import whisperx

_PROGRESS_MIN_PCT_DELTA = 5.0
_PROGRESS_MIN_INTERVAL_SECS = 15.0


def _fmt_duration(seconds: float) -> str:
    total = max(0, int(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours}h{minutes:02d}m{secs:02d}s"
    if minutes:
        return f"{minutes}m{secs:02d}s"
    return f"{secs}s"


def _make_progress_printer(label: str) -> Callable[[float], None]:
    start = time.monotonic()
    state = {"last_pct": -1.0, "last_time": start}

    def _progress_callback(pct: float) -> None:
        now = time.monotonic()
        elapsed = now - start
        is_first = state["last_pct"] < 0.0
        is_last = pct >= 100.0
        delta_ok = (pct - state["last_pct"]) >= _PROGRESS_MIN_PCT_DELTA
        interval_ok = (now - state["last_time"]) >= _PROGRESS_MIN_INTERVAL_SECS
        if not (is_first or is_last or delta_ok or interval_ok):
            return
        eta = elapsed * (100.0 - pct) / pct if pct > 0.0 else 0.0
        print(
            f"{label}: {pct:.0f}% (elapsed {_fmt_duration(elapsed)}, ETA {_fmt_duration(eta)})",
            flush=True,
        )
        state["last_pct"] = pct
        state["last_time"] = now

    return _progress_callback


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Align a WhisperX raw transcription to word-level timestamps."
    )
    parser.add_argument("audio", type=Path, help="Path to the original audio file.")
    parser.add_argument("raw_json", type=Path, help="Path to *_raw.json.")
    parser.add_argument(
        "--device", default="cpu",
        help="Inference device, e.g. cpu or cuda (default: cpu).",
    )
    parser.add_argument(
        "--align-model", default=None,
        help=(
            "Hugging Face wav2vec2 CTC model or torchaudio pipeline name. "
            "Required for languages without a WhisperX default, e.g. bn "
            "(default: the WhisperX default for the language)."
        ),
    )
    parser.add_argument(
        "--output", type=Path, default=None,
        help="Output JSON path. Defaults to <stem>_aligned.json.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    audio_file = args.audio.expanduser().resolve()
    raw_file = args.raw_json.expanduser().resolve()

    if not audio_file.is_file():
        print(f"ERROR: Audio file not found: {audio_file}", file=sys.stderr)
        return 1
    if not raw_file.is_file():
        print(f"ERROR: Raw transcription not found: {raw_file}", file=sys.stderr)
        return 1

    output_file = (
        args.output.expanduser().resolve()
        if args.output
        else raw_file.with_name(
            f"{raw_file.name[:-len('_raw.json')]}_aligned.json"
            if raw_file.name.endswith("_raw.json")
            else f"{raw_file.stem}_aligned.json"
        )
    )
    output_file.parent.mkdir(parents=True, exist_ok=True)

    print(f"Audio: {audio_file}")
    print(f"Raw transcription: {raw_file}")
    print("Loading audio...")
    audio = whisperx.load_audio(str(audio_file))

    with raw_file.open("r", encoding="utf-8") as handle:
        result = json.load(handle)

    language = result.get("language")
    if not language:
        print("ERROR: Raw transcription does not contain a language code.", file=sys.stderr)
        return 1

    model_label = args.align_model or "WhisperX default"
    print(f"Loading alignment model for language: {language} ({model_label})...")
    try:
        model_a, metadata = whisperx.load_align_model(
            language_code=language,
            device=args.device,
            model_name=args.align_model,
        )
    except ValueError as error:
        print(f"ERROR: Could not load an alignment model for language '{language}'.", file=sys.stderr)
        print(f"       {error}", file=sys.stderr)
        if args.align_model:
            print(
                "       Check the model name and that Hugging Face can be reached.",
                file=sys.stderr,
            )
        else:
            print(
                "       WhisperX has no default alignment model for this language. Pass a\n"
                "       wav2vec2 CTC model fine-tuned on it with --align-model\n"
                "       (run_pipeline.ps1 -AlignModel, or pipeline.alignModel in settings).",
                file=sys.stderr,
            )
        return 1

    print("Performing alignment...")
    progress_cb = _make_progress_printer("Align")
    aligned = whisperx.align(
        result["segments"],
        model_a,
        metadata,
        audio,
        args.device,
        return_char_alignments=False,
        progress_callback=progress_cb,
    )

    with output_file.open("w", encoding="utf-8") as handle:
        json.dump(aligned, handle, ensure_ascii=False, indent=2)

    print("Alignment complete.")
    print(f"Created: {output_file}")
    print(f"Segments: {len(aligned.get('segments', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
