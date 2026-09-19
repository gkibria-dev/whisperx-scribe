"""Transcribe an audio file with WhisperX.

This is stage 1 of the pipeline. It creates <audio_stem>_raw.json.
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
        description="Transcribe an audio file with WhisperX."
    )
    parser.add_argument("audio", type=Path, help="Path to the input audio file.")
    parser.add_argument(
        "--model", default="medium",
        help="Whisper/faster-whisper model name or path (default: medium).",
    )
    parser.add_argument(
        "--language", default=None,
        help="Language code, e.g. en. Omit to let WhisperX detect it.",
    )
    parser.add_argument(
        "--device", default="cpu",
        help="Inference device, e.g. cpu or cuda (default: cpu).",
    )
    parser.add_argument(
        "--compute-type", default="int8",
        help="CTranslate2 compute type (default: int8).",
    )
    parser.add_argument(
        "--output", type=Path, default=None,
        help="Output JSON path. Defaults to <audio>_raw.json.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    audio_file = args.audio.expanduser().resolve()

    if not audio_file.is_file():
        print(f"ERROR: Audio file not found: {audio_file}", file=sys.stderr)
        return 1

    output_file = (
        args.output.expanduser().resolve()
        if args.output
        else audio_file.with_name(f"{audio_file.stem}_raw.json")
    )
    output_file.parent.mkdir(parents=True, exist_ok=True)

    print(f"Audio: {audio_file}")
    print(f"Output: {output_file}")
    print("Loading audio...")
    audio = whisperx.load_audio(str(audio_file))

    print(
        f"Loading WhisperX model: {args.model} "
        f"(device={args.device}, compute_type={args.compute_type})..."
    )
    model = whisperx.load_model(
        args.model,
        args.device,
        compute_type=args.compute_type,
    )

    print("Transcribing...")
    progress_cb = _make_progress_printer("Transcribe")
    result = model.transcribe(audio, language=args.language, progress_callback=progress_cb)

    with output_file.open("w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)

    print(f"Transcription complete. Segments: {len(result.get('segments', []))}")
    print(f"Created: {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
