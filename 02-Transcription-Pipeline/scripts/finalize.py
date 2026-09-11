"""Create a readable speaker-labelled transcript from diarized JSON.

Stage 4 of the pipeline. Creates <stem>_final.txt.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a human-readable transcript from *_diarized.json."
    )
    parser.add_argument("diarized_json", type=Path, help="Path to *_diarized.json.")
    parser.add_argument(
        "--output", type=Path, default=None,
        help="Output text path. Defaults to <stem>_final.txt.",
    )
    return parser.parse_args()


def format_time(seconds: float | int | None) -> str:
    if seconds is None:
        return "??:??:??"

    total = max(0, int(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def extract_turns(data: dict[str, Any]) -> list[dict[str, Any]]:
    turns: list[dict[str, Any]] = []

    for segment in data.get("segments", []):
        words = segment.get("words", [])
        current_speaker = None
        current_words: list[str] = []
        start = None
        end = None

        for word in words:
            text = str(word.get("word", "")).strip()
            speaker = word.get("speaker")

            if not text or not speaker:
                continue

            if speaker != current_speaker:
                if current_speaker and current_words:
                    turns.append(
                        {
                            "speaker": current_speaker,
                            "start": start,
                            "end": end,
                            "text": " ".join(current_words).strip(),
                        }
                    )

                current_speaker = speaker
                current_words = [text]
                start = word.get("start")
            else:
                current_words.append(text)

            end = word.get("end")

        if current_speaker and current_words:
            turns.append(
                {
                    "speaker": current_speaker,
                    "start": start,
                    "end": end,
                    "text": " ".join(current_words).strip(),
                }
            )

    return turns


def merge_adjacent_turns(turns: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: list[dict[str, Any]] = []

    for turn in turns:
        if not turn["text"]:
            continue

        if merged and merged[-1]["speaker"] == turn["speaker"]:
            merged[-1]["end"] = turn["end"]
            merged[-1]["text"] += " " + turn["text"]
        else:
            merged.append(turn.copy())

    return merged


def main() -> int:
    args = parse_args()
    diarized_file = args.diarized_json.expanduser().resolve()

    if not diarized_file.is_file():
        print(f"ERROR: Diarized transcript not found: {diarized_file}", file=sys.stderr)
        return 1

    output_file = (
        args.output.expanduser().resolve()
        if args.output
        else diarized_file.with_name(
            f"{diarized_file.name[:-len('_diarized.json')]}_final.txt"
            if diarized_file.name.endswith("_diarized.json")
            else f"{diarized_file.stem}_final.txt"
        )
    )
    output_file.parent.mkdir(parents=True, exist_ok=True)

    print("Loading diarized transcript...")
    with diarized_file.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    turns = merge_adjacent_turns(extract_turns(data))

    with output_file.open("w", encoding="utf-8") as handle:
        for turn in turns:
            handle.write(
                f"[{format_time(turn['start'])} - {format_time(turn['end'])}] "
                f"{turn['speaker']}\n"
            )
            handle.write(f"{turn['text']}\n\n")

    print("Final transcript created.")
    print(f"Created: {output_file}")
    print(f"Speaker turns: {len(turns)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
