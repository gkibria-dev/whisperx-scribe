# Reference: output files

The files produced by one pipeline run. `<stem>` is the audio file name without its extension.

| File | Written by | Format | Read by |
|---|---|---|---|
| `<stem>_raw.json` | `transcribe.py` | JSON, UTF-8, indented | `align_and_merge.py` |
| `<stem>_aligned.json` | `align_and_merge.py` | JSON, UTF-8, indented | `diarize.py` |
| `<stem>_diarized.json` | `diarize.py` | JSON, UTF-8, indented | `finalize.py` |
| `<stem>_final.txt` | `finalize.py` | Plain text, UTF-8 | People |

Location: see `-OutputDirectory` in [run-pipeline.md](run-pipeline.md#-outputdirectory). Every
run overwrites files with the same names. All four files are kept. `.gitignore` excludes
`*_raw.json`, `*_aligned.json`, `*_diarized.json` and `*_final.txt`.

Non-ASCII text is written as-is, not as `\u` escapes.

## `<stem>_raw.json`

```json
{
  "segments": [
    { "text": " Hello, this is a short test.", "start": 0.031, "end": 4.52, "avg_logprob": -0.21 }
  ],
  "language": "en"
}
```

| Key | Type | Meaning |
|---|---|---|
| `segments` | array | One entry per voice-activity chunk |
| `segments[].text` | string | Transcribed text, often with a leading space |
| `segments[].start`, `segments[].end` | number | Seconds from the start of the audio, 3 decimals |
| `segments[].avg_logprob` | number | Average token log probability of the chunk. Closer to 0 means more confident. |
| `language` | string | The language code that was given, or the detected one. **Required by stage 2.** |

## `<stem>_aligned.json`

```json
{
  "segments": [
    {
      "start": 0.091, "end": 0.872, "text": " Hello, this is a short test.",
      "words": [ { "word": "Hello,", "start": 0.091, "end": 0.371, "score": 0.389 } ],
      "avg_logprob": -0.21
    }
  ],
  "word_segments": [ { "word": "Hello,", "start": 0.091, "end": 0.371, "score": 0.389 } ]
}
```

| Key | Type | Meaning |
|---|---|---|
| `segments` | array | Segments split at sentence boundaries, with refined timings |
| `segments[].words` | array | Words in the segment. **Required by stage 3.** |
| `segments[].words[].word` | string | The word, with attached punctuation |
| `segments[].words[].start`, `.end` | number | Seconds. Absent for tokens that could not be aligned, such as some numbers and symbols. |
| `segments[].words[].score` | number | Alignment confidence from 0 to 1. Absent when timing is absent. |
| `segments[].avg_logprob` | number | Carried over from the stage 1 chunk this segment came from |
| `word_segments` | array | All words from all segments, in order |

There is no `language` key.

## `<stem>_diarized.json`

The aligned structure, plus speaker labels:

| Key | Type | Meaning |
|---|---|---|
| `segments[].speaker` | string | `SPEAKER_00`, `SPEAKER_01`, … Absent when the segment overlaps no diarized speech. |
| `segments[].words[].speaker` | string | The speaker of the word. **Required by stage 4.** Absent when the word has no timing or overlaps no diarized speech. |

Speaker numbers are assigned by the diarization model. They are consistent within one run but
say nothing about who is who.

## `<stem>_final.txt`

```text
[00:00:00 - 00:00:08] SPEAKER_00
Hello, this is a short test of the WhisperX transcription pipeline.

[00:00:09 - 00:00:17] SPEAKER_01
Great. The sample contains two speakers, clear pauses, and ordinary English sentences.

```

| Rule | Detail |
|---|---|
| Turn header | `[HH:MM:SS - HH:MM:SS] <speaker>`. Seconds are truncated, not rounded. |
| Unknown time | `??:??:??` when the first or last word of the turn has no timing |
| Turn text | Words joined with single spaces |
| Separator | One blank line after each turn |
| Turn boundaries | A new turn starts when the word speaker changes. Consecutive turns by the same speaker, including across segments, are merged. |
| Words left out | Words with no `speaker`, and empty words |
