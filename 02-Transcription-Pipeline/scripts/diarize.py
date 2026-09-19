"""Run speaker diarization on an aligned WhisperX transcript.

Stage 3 of the pipeline. Creates <stem>_diarized.json.

Authentication:
    1. --hf-token, when explicitly supplied; otherwise
    2. HF_TOKEN environment variable; otherwise
    3. securely prompt for the token when run interactively.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
import time
from pathlib import Path
from typing import Callable

import whisperx
from whisperx.diarize import DiarizationPipeline

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
        phase = " [segmentation]" if pct < 50.0 else " [embeddings]"
        print(
            f"{label}: {pct:.0f}%{phase} (elapsed {_fmt_duration(elapsed)}, ETA {_fmt_duration(eta)})",
            flush=True,
        )
        state["last_pct"] = pct
        state["last_time"] = now

    return _progress_callback


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run speaker diarization and assign speakers to an aligned transcript."
    )

    parser.add_argument(
        "audio",
        type=Path,
        help="Path to the original audio file.",
    )

    parser.add_argument(
        "aligned_json",
        type=Path,
        help="Path to *_aligned.json.",
    )

    parser.add_argument(
        "--device",
        default="cpu",
        help="Inference device, e.g. cpu or cuda (default: cpu).",
    )

    parser.add_argument(
        "--hf-token",
        default=None,
        help="Optional Hugging Face access token.",
    )

    parser.add_argument(
        "--min-speakers",
        type=int,
        default=None,
        help="Optional minimum number of speakers.",
    )

    parser.add_argument(
        "--max-speakers",
        type=int,
        default=None,
        help="Optional maximum number of speakers.",
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output JSON path. Defaults to <stem>_diarized.json.",
    )

    return parser.parse_args()


def get_hugging_face_token(explicit_token: str | None) -> str:
    """Resolve the Hugging Face token without ever printing it."""
    token = explicit_token or os.getenv("HF_TOKEN")

    if token:
        return token.strip()

    if not sys.stdin.isatty():
        print(
            "ERROR: Hugging Face token is required for speaker diarization.",
            file=sys.stderr,
        )
        print(
            "Supply --hf-token or set the HF_TOKEN environment variable.",
            file=sys.stderr,
        )
        return ""

    try:
        token = getpass.getpass(
            "Enter your Hugging Face access token: "
        ).strip()
    except (EOFError, KeyboardInterrupt):
        print("\nERROR: No Hugging Face token was supplied.", file=sys.stderr)
        return ""

    return token


def main() -> int:
    args = parse_args()

    audio_file = args.audio.expanduser().resolve()
    aligned_file = args.aligned_json.expanduser().resolve()

    if not audio_file.is_file():
        print(
            f"ERROR: Audio file not found: {audio_file}",
            file=sys.stderr,
        )
        return 1

    if not aligned_file.is_file():
        print(
            f"ERROR: Aligned transcript not found: {aligned_file}",
            file=sys.stderr,
        )
        return 1

    if args.min_speakers is not None and args.min_speakers < 1:
        print("ERROR: --min-speakers must be at least 1.", file=sys.stderr)
        return 1

    if args.max_speakers is not None and args.max_speakers < 1:
        print("ERROR: --max-speakers must be at least 1.", file=sys.stderr)
        return 1

    if (
        args.min_speakers is not None
        and args.max_speakers is not None
        and args.min_speakers > args.max_speakers
    ):
        print(
            "ERROR: --min-speakers cannot be greater than --max-speakers.",
            file=sys.stderr,
        )
        return 1

    output_file = (
        args.output.expanduser().resolve()
        if args.output
        else aligned_file.with_name(
            (
                f"{aligned_file.name[:-len('_aligned.json')]}_diarized.json"
                if aligned_file.name.endswith("_aligned.json")
                else f"{aligned_file.stem}_diarized.json"
            )
        )
    )

    output_file.parent.mkdir(parents=True, exist_ok=True)

    token = get_hugging_face_token(args.hf_token)

    if not token:
        return 1

    print(f"Audio: {audio_file}")
    print(f"Aligned transcript: {aligned_file}")
    print("Loading audio...")
    audio = whisperx.load_audio(str(audio_file))

    with aligned_file.open("r", encoding="utf-8") as handle:
        result = json.load(handle)

    print(f"Loading diarization model (device={args.device})...")
    diarize_model = DiarizationPipeline(
        token=token,
        device=args.device,
    )

    diarization_kwargs: dict[str, int | Callable[[float], None]] = {}

    if args.min_speakers is not None:
        diarization_kwargs["min_speakers"] = args.min_speakers

    if args.max_speakers is not None:
        diarization_kwargs["max_speakers"] = args.max_speakers

    diarization_kwargs["progress_callback"] = _make_progress_printer("Diarize")

    print("Running speaker diarization...")
    diarize_segments = diarize_model(
        audio,
        **diarization_kwargs,
    )

    print("Assigning speakers to transcript...")
    result = whisperx.assign_word_speakers(
        diarize_segments,
        result,
    )

    with output_file.open("w", encoding="utf-8") as handle:
        json.dump(
            result,
            handle,
            ensure_ascii=False,
            indent=2,
        )

    print("Diarization complete.")
    print(f"Created: {output_file}")
    print(f"Segments: {len(result.get('segments', []))}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
