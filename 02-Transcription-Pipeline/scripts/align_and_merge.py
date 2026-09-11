"""Align a WhisperX transcription to word-level timestamps.

Stage 2 of the pipeline. Creates <stem>_aligned.json.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import whisperx


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

    print(f"Loading alignment model for language: {language}...")
    model_a, metadata = whisperx.load_align_model(
        language_code=language,
        device=args.device,
    )

    print("Performing alignment...")
    aligned = whisperx.align(
        result["segments"],
        model_a,
        metadata,
        audio,
        args.device,
        return_char_alignments=False,
    )

    with output_file.open("w", encoding="utf-8") as handle:
        json.dump(aligned, handle, ensure_ascii=False, indent=2)

    print("Alignment complete.")
    print(f"Created: {output_file}")
    print(f"Segments: {len(aligned.get('segments', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
